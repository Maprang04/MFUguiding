"""End-to-end zone navigation demo using simulated controller observations."""

import argparse
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent
sys.path.insert(0, str(ROOT / "navigation"))

from astar import FloorGrid, find_path_meters, simplify_path  # noqa: E402
from route_visualizer import RouteVisualizer  # noqa: E402
from positioning.roaming_tracker import RoamingTracker  # noqa: E402
from positioning.rssi_filter import InvalidRssiError, RssiMedianFilter  # noqa: E402
from positioning.zone_estimator import ZoneEstimator, load_zone_config  # noqa: E402


def snap_to_walkable(grid, position):
    cell = grid.nearest_walkable(*grid.meter_to_cell(*position))
    return grid.cell_to_meter(*cell)


def build_route(grid, start, goal):
    path = find_path_meters(grid, start, goal)
    return simplify_path(path) if path else None


def run_simulation(observations, config, destination_key):
    destination = config["destinations"].get(destination_key)
    if destination is None:
        choices = ", ".join(sorted(config["destinations"]))
        raise KeyError(f"Unknown destination {destination_key!r}; choose one of: {choices}")

    rssi_cfg = config["rssi"]
    rssi_filter = RssiMedianFilter(
        window_size=rssi_cfg["window_size"],
        valid_min_exclusive=rssi_cfg["valid_min_exclusive"],
        valid_max_exclusive=rssi_cfg["valid_max_exclusive"],
    )
    tracker = RoamingTracker(config["roaming"]["required_confirmations"])
    estimator = ZoneEstimator(config)
    grid = FloorGrid(
        str(ROOT / "floorplan" / "occupancy_grid.npy"),
        str(ROOT / "floorplan" / "grid_config.json"),
    )
    visualizer = RouteVisualizer(
        ROOT / "floorplan" / "floorplan_clean.png",
        ROOT / "floorplan" / "grid_config.json",
    )
    goal = snap_to_walkable(grid, destination["position"])
    client_positions = {}
    routes_recalculated = 0

    print(f"Destination: {destination['label']} at {goal}")
    print(f"Roaming confirmation: {tracker.required_confirmations} consecutive readings\n")

    for index, observation in enumerate(observations, start=1):
        client_id = observation["client_id"]
        detected_ap = observation["associated_ap"]
        try:
            detected_median_rssi = rssi_filter.update(client_id, detected_ap, observation["rssi"])
        except InvalidRssiError as exc:
            print(f"[{index:02d}] ignored invalid observation: {exc}")
            continue

        roaming = tracker.update(client_id, detected_ap)
        # While a new AP is only a candidate, continue estimating from the
        # last confirmed AP and its own RSSI window. Never mix AP2 RSSI with
        # an AP3 zone estimate.
        median_rssi = rssi_filter.median(client_id, roaming.current_ap)
        if median_rssi is None:
            median_rssi = detected_median_rssi
        previous_position = client_positions.get(client_id)
        previous_ap = roaming.previous_ap if roaming.roaming_confirmed else None
        estimate = estimator.estimate(
            current_ap=roaming.current_ap,
            median_rssi=median_rssi,
            previous_ap=previous_ap,
            previous_position=previous_position,
        )
        position = snap_to_walkable(grid, estimate["position"])

        should_recalculate = previous_position is None or roaming.roaming_confirmed
        if should_recalculate:
            route = build_route(grid, position, goal)
            if route is None:
                raise RuntimeError(f"No route from {position} to {goal}")
            routes_recalculated += 1
            client_positions[client_id] = position
            route_image = visualizer.save(
                route,
                ROOT / "navigation_outputs" /
                f"{destination_key}_{routes_recalculated:02d}_{roaming.current_ap}.png",
                destination["label"],
            )
        else:
            route = None

        candidate = ""
        if roaming.candidate_ap:
            candidate = f" candidate={roaming.candidate_ap}({roaming.candidate_count}/{tracker.required_confirmations})"
        event = " ROAM CONFIRMED" if roaming.roaming_confirmed else ""
        print(
            f"[{index:02d}] detected={detected_ap} rssi={observation['rssi']} "
            f"detected_median={detected_median_rssi:g} confirmed={roaming.current_ap} "
            f"confirmed_median={median_rssi:g}{candidate}{event}"
        )
        print(
            f"     zone={estimate['zone']} band={estimate['signal_band']} "
            f"position={position} source={estimate['position_source']} "
            f"confidence={estimate['confidence']}"
        )
        if route is not None:
            print(f"     route recalculated: {len(route)} waypoints")
            for waypoint in route:
                print(f"       -> ({waypoint[0]:.2f}, {waypoint[1]:.2f})")
            print(f"     route map: {route_image.relative_to(ROOT)}")

    print(f"\nSimulation complete: {len(observations)} observations, {routes_recalculated} route calculations")
    return routes_recalculated


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input", default="simulator/observations.json")
    parser.add_argument("--config", default="positioning/zone_config.json")
    parser.add_argument("--destination", default="room_2")
    args = parser.parse_args()

    input_path = ROOT / args.input
    config_path = ROOT / args.config
    with input_path.open(encoding="utf-8") as stream:
        observations = json.load(stream)
    config = load_zone_config(config_path)
    run_simulation(observations, config, args.destination)


if __name__ == "__main__":
    main()
