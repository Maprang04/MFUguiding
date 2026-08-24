"""Stateful positioning engine shared by the HTTP API and tests."""

from __future__ import annotations

from dataclasses import dataclass
import math
from pathlib import Path
from threading import RLock

from navigation.astar import (
    FloorGrid,
    find_path_meters,
    route_is_walkable,
    simplify_path,
)
from positioning.roaming_tracker import RoamingTracker
from positioning.rssi_filter import RssiMedianFilter
from positioning.zone_estimator import ZoneEstimator, load_zone_config
from positioning.zone_classifier import ZoneClassifier
from positioning.multi_ap_positioner import MultiApPositioner


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
    distance_travelled: float = 0.0
    current_band: str | None = None
    candidate_band: str | None = None
    candidate_band_count: int = 0
    fingerprint_ap: str | None = None
    candidate_fingerprint_ap: str | None = None
    candidate_fingerprint_count: int = 0
    destination_proximity_count: int = 0


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
        roaming = self.config["roaming"]
        self.roaming = RoamingTracker(
            required_confirmations=roaming["required_confirmations"],
            reverse_confirmations=roaming.get("reverse_confirmations", 5),
            reverse_guard_observations=roaming.get(
                "reverse_guard_observations", 8
            ),
        )
        model_path = self.root / "models" / "zone_classifier.joblib"
        self.zone_classifier = ZoneClassifier(model_path) if model_path.exists() else None
        multi_ap_model_path = self.root / "models" / "hybrid_model.joblib"
        self.multi_ap_positioner = (
            MultiApPositioner(
                multi_ap_model_path,
                self.config.get("positioning", {}).get(
                    "calibrated_fingerprints", []
                ),
            )
            if multi_ap_model_path.exists()
            else None
        )
        self.estimator = ZoneEstimator(self.config, self.zone_classifier)
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
        simplified = simplify_path(path)
        # Never return a visual shortcut that crosses a blocked cell. The raw
        # grid path remains a safe fallback if simplification is unsafe.
        return simplified if route_is_walkable(self.grid, simplified) else path

    @staticmethod
    def _project_forward_to_route(current_position, route, proposed_position):
        """Project a noisy position onto the remaining route.

        The remaining route begins at the current marker, therefore the
        projection distance can never move behind the last accepted position.
        Returns (projected point, forward distance, lateral distance).
        """
        points = [tuple(current_position)]
        for point in route or []:
            point = tuple(point)
            if point != points[-1]:
                points.append(point)
        if len(points) < 2:
            return tuple(current_position), 0.0, math.hypot(
                proposed_position[0] - current_position[0],
                proposed_position[1] - current_position[1],
            )

        best_point = points[0]
        best_forward = 0.0
        best_lateral = float("inf")
        traversed = 0.0
        px, py = proposed_position
        for start, end in zip(points, points[1:]):
            dx = end[0] - start[0]
            dy = end[1] - start[1]
            length_squared = dx * dx + dy * dy
            if length_squared <= 1e-12:
                continue
            ratio = max(
                0.0,
                min(1.0, ((px - start[0]) * dx + (py - start[1]) * dy) / length_squared),
            )
            projected = (start[0] + ratio * dx, start[1] + ratio * dy)
            lateral = math.hypot(px - projected[0], py - projected[1])
            forward = traversed + ratio * math.sqrt(length_squared)
            if lateral < best_lateral:
                best_point = projected
                best_forward = forward
                best_lateral = lateral
            traversed += math.sqrt(length_squared)
        return best_point, best_forward, best_lateral

    @staticmethod
    def _point(position):
        return {"x": float(position[0]), "y": float(position[1])}

    def health(self):
        return {
            "status": "ok",
            "service": "python-positioning",
            "active_sessions": len(self.sessions),
            "zone_model_loaded": self.zone_classifier is not None,
            "multi_ap_model_loaded": self.multi_ap_positioner is not None,
        }

    def configure(self, snapshot: dict):
        destinations = {}
        for item in snapshot.get("destinations", []):
            position = item.get("position") or {}
            destinations[item["id"]] = {
                "label": item["label"],
                "position": [float(position["x"]), float(position["y"])],
            }

        ap_zones = {}
        for item in snapshot.get("access_points", []):
            anchors = item.get("anchors") or {}
            ap_zones[item["name"]] = {
                "zone": item["zone"],
                "label": item.get("zoneLabel") or item["zone"],
                "start_anchor": [
                    float((item.get("startAnchor") or anchors["medium"])["x"]),
                    float((item.get("startAnchor") or anchors["medium"])["y"]),
                ],
                "anchors": {
                    band: [
                        float(anchors[band]["x"]),
                        float(anchors[band]["y"]),
                    ]
                    for band in ("near", "medium", "edge")
                },
            }

        transitions = {
            key: [[float(point["x"]), float(point["y"])]]
            for key, point in snapshot.get("transitions", {}).items()
        }
        if not destinations or not ap_zones:
            raise PositioningError(
                400,
                "INVALID_CONFIGURATION",
                "At least one destination and access point are required",
            )

        with self.lock:
            self.config["destinations"] = destinations
            self.config["ap_zones"] = ap_zones
            self.config["transitions"] = transitions
            self.estimator = ZoneEstimator(self.config, self.zone_classifier)
        return {
            "configured": True,
            "destinations": len(destinations),
            "access_points": len(ap_zones),
            "transitions": len(transitions),
        }

    def create_session(
        self,
        session_id: str,
        client_id: str,
        destination_id: str,
        start_position=None,
    ):
        if not session_id or not client_id:
            raise PositioningError(400, "INVALID_REQUEST", "session_id and client_id are required")
        self._destination(destination_id)
        with self.lock:
            if session_id in self.sessions:
                raise PositioningError(409, "SESSION_EXISTS", "Positioning session already exists")
            state = SessionState(session_id, client_id, destination_id)
            if start_position is not None:
                state.current_position = self._snap(
                    (float(start_position["x"]), float(start_position["y"]))
                )
                state.route = self._route(state.current_position, destination_id)
            self.sessions[session_id] = state
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
                "distance_travelled": state.distance_travelled,
            }

    def advance_progress(self, session_id: str, distance_meters):
        distance = float(distance_meters)
        if not math.isfinite(distance) or distance <= 0 or distance > 20:
            raise PositioningError(
                400,
                "INVALID_PROGRESS",
                "distance_meters must be greater than 0 and no more than 20",
            )
        with self.lock:
            state = self._session(session_id)
            if state.current_position is None or not state.route:
                raise PositioningError(409, "ROUTE_NOT_READY", "A route is required before progress")

            points = [state.current_position]
            for point in state.route:
                point = tuple(point)
                if point != points[-1]:
                    points.append(point)
            remaining_distance = distance
            index = 1
            current = points[0]
            while index < len(points) and remaining_distance > 0:
                target = points[index]
                segment = math.hypot(target[0] - current[0], target[1] - current[1])
                if segment <= remaining_distance + 1e-9:
                    current = target
                    remaining_distance -= segment
                    index += 1
                else:
                    ratio = remaining_distance / segment
                    current = (
                        current[0] + (target[0] - current[0]) * ratio,
                        current[1] + (target[1] - current[1]) * ratio,
                    )
                    remaining_distance = 0

            consumed = distance - remaining_distance
            destination = self._snap(self._destination(state.destination_id)["position"])
            arrived = index >= len(points) and math.hypot(
                current[0] - destination[0], current[1] - destination[1]
            ) <= 0.35
            state.current_position = destination if arrived else current
            state.distance_travelled += consumed
            state.route = [state.current_position] + ([] if arrived else points[index:])
            return {
                "estimated_position": self._point(state.current_position),
                "route": [self._point(point) for point in state.route],
                "distance_delta": consumed,
                "distance_travelled": state.distance_travelled,
                "arrived": arrived,
                "position_source": "step_route_progress",
            }

    def submit_observation(
        self,
        session_id: str,
        associated_ap: str,
        rssi,
        rssi_readings=None,
    ):
        with self.lock:
            state = self._session(session_id)
            # Filter and roaming state are scoped to a navigation session, so
            # starting a new trip on the same phone never inherits old RSSI.
            detected_median = self.rssi_filter.update(state.session_id, associated_ap, rssi)
            if isinstance(rssi_readings, dict):
                for ap_name, ap_rssi in rssi_readings.items():
                    if ap_name in self.config["ap_zones"] and ap_name != associated_ap:
                        self.rssi_filter.update(state.session_id, ap_name, ap_rssi)
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
            initial_zone_anchor_used = state.current_position is None
            if initial_zone_anchor_used:
                zone_config = self.config["ap_zones"][roaming.current_ap]
                position = self._snap(
                    zone_config.get("start_anchor", zone_config["anchors"]["medium"])
                )
                estimate["position_source"] = "zone_hallway_start_anchor"
                estimate["confidence"] = "low"
            band_position_confirmed = False
            stable_zone_navigation = bool(
                self.config.get("positioning", {}).get(
                    "stable_zone_navigation", False
                )
            )
            if state.current_position is None:
                state.current_band = estimate["signal_band"]
                state.candidate_band = None
                state.candidate_band_count = 0
            elif roaming.roaming_confirmed:
                # Keep the transition anchor first. Subsequent stable RSSI
                # observations may refine the point inside the new zone.
                state.current_band = None
                state.candidate_band = None
                state.candidate_band_count = 0
            elif stable_zone_navigation:
                # In zone-only navigation, RSSI variation must not drag the
                # marker among near/medium/edge anchors. Keep the last accepted
                # point until roaming to another AP is confirmed.
                position = state.current_position
                recalculate = False
                state.candidate_band = None
                state.candidate_band_count = 0
                estimate["position_source"] = "stable_zone_lock"
                estimate["confidence"] = "medium"
            else:
                observed_band = estimate["signal_band"]
                if observed_band == state.current_band:
                    state.candidate_band = None
                    state.candidate_band_count = 0
                    position = state.current_position
                else:
                    if observed_band == state.candidate_band:
                        state.candidate_band_count += 1
                    else:
                        state.candidate_band = observed_band
                        state.candidate_band_count = 1
                    confirmations = int(
                        self.config.get("positioning", {}).get(
                            "band_confirmations", 3
                        )
                    )
                    if state.candidate_band_count >= confirmations:
                        state.current_band = observed_band
                        state.candidate_band = None
                        state.candidate_band_count = 0
                        band_position_confirmed = True
                        recalculate = True
                        estimate["position_source"] = "stable_rssi_band_anchor"
                    else:
                        position = state.current_position

            multi_ap_result = None
            multi_ap_applied = False
            fingerprint_zone_confirmed = False
            fingerprint_transition_confirmed = False
            if self.multi_ap_positioner is not None and isinstance(rssi_readings, dict):
                filtered_readings = {
                    ap_name: self.rssi_filter.median(state.session_id, ap_name)
                    for ap_name in self.multi_ap_positioner.ap_names
                }
                if all(value is not None for value in filtered_readings.values()):
                    multi_ap_result = self.multi_ap_positioner.predict(filtered_readings)

            if state.fingerprint_ap is None:
                # Start from the AP confirmed by association. A disagreeing
                # fingerprint must prove itself over multiple observations.
                state.fingerprint_ap = roaming.current_ap

            if multi_ap_result is not None:
                observed_fingerprint_ap = multi_ap_result["strongest_ap"]
                if observed_fingerprint_ap == state.fingerprint_ap:
                    state.candidate_fingerprint_ap = None
                    state.candidate_fingerprint_count = 0
                    fingerprint_zone_confirmed = True
                else:
                    if observed_fingerprint_ap == state.candidate_fingerprint_ap:
                        state.candidate_fingerprint_count += 1
                    else:
                        state.candidate_fingerprint_ap = observed_fingerprint_ap
                        state.candidate_fingerprint_count = 1
                    required = int(
                        self.config.get("positioning", {}).get(
                            "fingerprint_zone_confirmations", 3
                        )
                    )
                    if state.candidate_fingerprint_count >= required:
                        state.fingerprint_ap = observed_fingerprint_ap
                        state.candidate_fingerprint_ap = None
                        state.candidate_fingerprint_count = 0
                        fingerprint_zone_confirmed = True
                        fingerprint_transition_confirmed = True

            # A complete three-AP fingerprint is more informative than the AP
            # the phone is currently associated with. Phones can remain stuck
            # to an old AP near a zone boundary, so association is only the
            # fallback when a complete scan is unavailable.
            if (
                multi_ap_result is not None
                and multi_ap_result["strongest_ap"] == state.fingerprint_ap
                and fingerprint_zone_confirmed
                and not roaming.roaming_confirmed
                and not stable_zone_navigation
            ):
                fingerprint_ap = multi_ap_result["strongest_ap"]
                fingerprint_rssi = filtered_readings[fingerprint_ap]
                fingerprint_estimate = self.estimator.estimate(
                    fingerprint_ap,
                    fingerprint_rssi,
                    previous_ap=roaming.previous_ap,
                    previous_position=state.current_position,
                )
                predicted = self._snap(multi_ap_result["position"])
                trusted_calibration_transition = bool(
                    multi_ap_result.get("calibration_used")
                    and fingerprint_transition_confirmed
                )
                destination = self._snap(
                    self._destination(state.destination_id)["position"]
                )
                arrival_guard_radius = float(
                    self.config.get("positioning", {}).get(
                        "arrival_guard_radius_m", 1.5
                    )
                )
                near_destination = math.hypot(
                    predicted[0] - destination[0],
                    predicted[1] - destination[1],
                ) <= arrival_guard_radius
                arrival_confirmations = int(
                    self.config.get("positioning", {}).get(
                        "arrival_confirmations", 5
                    )
                )
                if near_destination:
                    if trusted_calibration_transition:
                        # The loading screen already collected the three
                        # observations needed to confirm this surveyed anchor.
                        state.destination_proximity_count = arrival_confirmations
                    else:
                        state.destination_proximity_count += 1
                else:
                    state.destination_proximity_count = 0
                arrival_guard_active = (
                    near_destination
                    and state.destination_proximity_count < arrival_confirmations
                )
                if state.current_position is not None and not trusted_calibration_transition:
                    dx = predicted[0] - state.current_position[0]
                    dy = predicted[1] - state.current_position[1]
                    distance = math.hypot(dx, dy)
                    max_update = float(
                        self.config.get("positioning", {}).get(
                            "max_fingerprint_update_m", 0.75
                        )
                    )
                    if distance > max_update:
                        ratio = max_update / distance
                        predicted = self._snap(
                            (
                                state.current_position[0] + dx * ratio,
                                state.current_position[1] + dy * ratio,
                            )
                        )
                    if state.route:
                        projected, forward, lateral = self._project_forward_to_route(
                            state.current_position,
                            state.route,
                            predicted,
                        )
                        route_tolerance = float(
                            self.config.get("positioning", {}).get(
                                "route_snap_tolerance_m", 1.5
                            )
                        )
                        if lateral <= route_tolerance:
                            predicted = projected
                        elif not fingerprint_transition_confirmed:
                            # A same-zone position far from the route is more
                            # likely RSSI noise. Hold until a zone transition
                            # is confirmed instead of creating a wrong route.
                            predicted = state.current_position
                prediction_delta = (
                    float("inf")
                    if state.current_position is None
                    else math.hypot(
                        predicted[0] - state.current_position[0],
                        predicted[1] - state.current_position[1],
                    )
                )
                min_update = float(
                    self.config.get("positioning", {}).get(
                        "min_fingerprint_update_m", 0.20
                    )
                )
                if prediction_delta >= min_update and not arrival_guard_active:
                    position = predicted
                    recalculate = True
                    estimate["zone"] = fingerprint_estimate["zone"]
                    estimate["label"] = fingerprint_estimate["label"]
                    estimate["position_source"] = "three_ap_fingerprint"
                    estimate["confidence"] = "medium"
                    multi_ap_applied = True
                elif arrival_guard_active:
                    # Keep the last safe estimate (or the connected-AP anchor
                    # for a new session) until destination evidence is stable.
                    position = state.current_position or position
                    estimate["position_source"] = "arrival_guard_hold"
                    estimate["confidence"] = "low"
            elif multi_ap_result is None:
                state.destination_proximity_count = 0

            if (
                stable_zone_navigation
                and state.current_position is not None
                and multi_ap_result is not None
            ):
                # With a complete three-AP scan, keep both the marker and its
                # route locked while the fingerprint remains in the same
                # zone. This prevents small RSSI changes (and sticky roaming
                # association) from rebuilding a visibly jumping route.
                stable_ap = state.fingerprint_ap or roaming.current_ap
                stable_zone = self.config["ap_zones"][stable_ap]
                estimate["zone"] = stable_zone["zone"]
                estimate["label"] = stable_zone["label"]
                if fingerprint_transition_confirmed:
                    position = self._snap(
                        stable_zone.get(
                            "start_anchor", stable_zone["anchors"]["medium"]
                        )
                    )
                    recalculate = True
                    estimate["position_source"] = "confirmed_zone_transition"
                    estimate["confidence"] = "medium"
                    multi_ap_applied = True
                else:
                    position = state.current_position
                    recalculate = False
                    estimate["position_source"] = "stable_zone_lock"
                    estimate["confidence"] = "medium"

            if initial_zone_anchor_used:
                # The first complete Wi-Fi reading may identify the zone, but
                # an RSSI-derived point inside that zone is too uncertain for
                # a route origin. Start at the configured hallway centre and
                # let later stable fingerprints refine movement from there.
                start_ap = state.fingerprint_ap or roaming.current_ap
                start_zone = self.config["ap_zones"][start_ap]
                position = self._snap(
                    start_zone.get("start_anchor", start_zone["anchors"]["medium"])
                )
                estimate["zone"] = start_zone["zone"]
                estimate["label"] = start_zone["label"]
                estimate["position_source"] = "zone_hallway_start_anchor"
                estimate["confidence"] = "medium" if multi_ap_applied else "low"
                recalculate = True
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
                "position_band": state.current_band,
                "candidate_band": state.candidate_band,
                "candidate_band_count": state.candidate_band_count,
                "band_position_confirmed": band_position_confirmed,
                "multi_ap_used": multi_ap_applied,
                "multi_ap_strongest_ap": (
                    multi_ap_result["strongest_ap"] if multi_ap_result else None
                ),
                "radio_strongest_ap": (
                    multi_ap_result.get("radio_strongest_ap")
                    if multi_ap_result else None
                ),
                "calibration_used": bool(
                    multi_ap_result and multi_ap_result.get("calibration_used")
                ),
                "calibration_id": (
                    multi_ap_result.get("calibration_id")
                    if multi_ap_result else None
                ),
                "fingerprint_ap": state.fingerprint_ap,
                "candidate_fingerprint_ap": state.candidate_fingerprint_ap,
                "candidate_fingerprint_count": state.candidate_fingerprint_count,
                "fingerprint_zone_confirmed": fingerprint_zone_confirmed,
                "fingerprint_transition_confirmed": fingerprint_transition_confirmed,
                "destination_proximity_count": state.destination_proximity_count,
                "arrival_guard_active": estimate["position_source"] == "arrival_guard_hold",
                "stable_zone_navigation": stable_zone_navigation,
                "median_rssi": median_rssi,
                "estimated_position": self._point(position),
                "position_source": estimate["position_source"],
                "confidence": estimate["confidence"],
                "model_confidence": estimate["model_confidence"],
                "zone_model_used": estimate["zone_model_used"],
                "model_agrees_with_ap": estimate["model_agrees_with_ap"],
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
            state.destination_proximity_count = 0
            if state.current_position is not None:
                state.route = self._route(state.current_position, destination_id)
            return self.get_session(session_id)

    def delete_session(self, session_id: str):
        with self.lock:
            self._session(session_id)
            del self.sessions[session_id]
            return {"deleted": True, "session_id": session_id}
