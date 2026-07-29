"""Stateful positioning engine shared by the HTTP API and tests."""

from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path
from threading import RLock

from navigation.astar import FloorGrid, find_path_meters, simplify_path
from positioning.roaming_tracker import RoamingTracker
from positioning.rssi_filter import RssiMedianFilter
from positioning.zone_estimator import ZoneEstimator, load_zone_config


ROOT = Path(__file__).resolve().parents[1]


class PositioningError(Exception):
    def __init__(self, status_code: int, code: str, message: str):
        super().__init__(message)
        self.status_code = status_code
        self.code = code


@dataclass
class SessionState:
    session_id: str
    client_id: str
    destination_id: str
    current_position: tuple[float, float] | None = None
    route: list[tuple[float, float]] | None = None
    last_result: dict | None = None


class PositioningService:
    def __init__(self, root: Path = ROOT):
        self.root = Path(root)
        self.config = load_zone_config(self.root / "positioning" / "zone_config.json")
        rssi = self.config["rssi"]
        self.rssi_filter = RssiMedianFilter(
            window_size=rssi["window_size"],
            valid_min_exclusive=rssi["valid_min_exclusive"],
            valid_max_exclusive=rssi["valid_max_exclusive"],
        )
        self.roaming = RoamingTracker(self.config["roaming"]["required_confirmations"])
        self.estimator = ZoneEstimator(self.config)
        self.grid = FloorGrid(
            str(self.root / "floorplan" / "occupancy_grid.npy"),
            str(self.root / "floorplan" / "grid_config.json"),
        )
        self.sessions: dict[str, SessionState] = {}
        self.lock = RLock()

    def _destination(self, destination_id: str) -> dict:
        destination = self.config["destinations"].get(destination_id)
        if destination is None:
            raise PositioningError(404, "DESTINATION_NOT_FOUND", "Destination does not exist")
        return destination

    def _session(self, session_id: str) -> SessionState:
        session = self.sessions.get(session_id)
        if session is None:
            raise PositioningError(404, "SESSION_NOT_FOUND", "Positioning session not found")
        return session

    def _snap(self, position) -> tuple[float, float]:
        cell = self.grid.nearest_walkable(*self.grid.meter_to_cell(*position))
        return self.grid.cell_to_meter(*cell)

    def _route(self, start, destination_id):
        goal = self._snap(self._destination(destination_id)["position"])
        path = find_path_meters(self.grid, start, goal)
        if not path:
            raise PositioningError(422, "ROUTE_NOT_FOUND", "No walkable route was found")
        return simplify_path(path)

    @staticmethod
    def _point(position):
        return {"x": float(position[0]), "y": float(position[1])}

    def health(self):
        return {
            "status": "ok",
            "service": "python-positioning",
            "active_sessions": len(self.sessions),
        }

    def create_session(self, session_id: str, client_id: str, destination_id: str):
        if not session_id or not client_id:
            raise PositioningError(400, "INVALID_REQUEST", "session_id and client_id are required")
        self._destination(destination_id)
        with self.lock:
            if session_id in self.sessions:
                raise PositioningError(409, "SESSION_EXISTS", "Positioning session already exists")
            self.sessions[session_id] = SessionState(session_id, client_id, destination_id)
            return self.get_session(session_id)

    def get_session(self, session_id: str):
        with self.lock:
            state = self._session(session_id)
            return {
                "session_id": state.session_id,
                "client_id": state.client_id,
                "destination_id": state.destination_id,
                "estimated_position": (
                    self._point(state.current_position) if state.current_position else None
                ),
                "route": [self._point(point) for point in (state.route or [])],
                "last_result": state.last_result,
            }

    def submit_observation(self, session_id: str, associated_ap: str, rssi):
        with self.lock:
            state = self._session(session_id)
            # Filter and roaming state are scoped to a navigation session, so
            # starting a new trip on the same phone never inherits old RSSI.
            detected_median = self.rssi_filter.update(state.session_id, associated_ap, rssi)
            roaming = self.roaming.update(state.session_id, associated_ap)
            median_rssi = self.rssi_filter.median(state.session_id, roaming.current_ap)
            if median_rssi is None:
                median_rssi = detected_median

            estimate = self.estimator.estimate(
                current_ap=roaming.current_ap,
                median_rssi=median_rssi,
                previous_ap=roaming.previous_ap if roaming.roaming_confirmed else None,
                previous_position=state.current_position,
            )
            position = self._snap(estimate["position"])
            recalculate = state.current_position is None or roaming.roaming_confirmed
            route = self._route(position, state.destination_id) if recalculate else None
            state.current_position = position
            if route is not None:
                state.route = route

            result = {
                "confirmed_ap": roaming.current_ap,
                "candidate_ap": roaming.candidate_ap,
                "candidate_count": roaming.candidate_count,
                "roaming_confirmed": roaming.roaming_confirmed,
                "previous_ap": roaming.previous_ap,
                "zone": estimate["zone"],
                "zone_label": estimate["label"],
                "signal_band": estimate["signal_band"],
                "median_rssi": median_rssi,
                "estimated_position": self._point(position),
                "position_source": estimate["position_source"],
                "confidence": estimate["confidence"],
                "route_recalculated": recalculate,
                "route": [self._point(point) for point in (route or [])],
            }
            state.last_result = result
            return result

    def change_destination(self, session_id: str, destination_id: str):
        self._destination(destination_id)
        with self.lock:
            state = self._session(session_id)
            state.destination_id = destination_id
            if state.current_position is not None:
                state.route = self._route(state.current_position, destination_id)
            return self.get_session(session_id)

    def delete_session(self, session_id: str):
        with self.lock:
            self._session(session_id)
            del self.sessions[session_id]
            return {"deleted": True, "session_id": session_id}
