"""
navigate_demo.py
------------------
End-to-end demo tying the three pieces together:

  1. WiFi reading -> roaming zone (strongest AP) + fingerprint position   [models/hybrid_model.joblib]
  2. Walkability check on the predicted position                          [floorplan/occupancy_grid.npy]
  3. A* path from that position to a destination                          [navigation/astar.py]

Run from the project root:  python3 navigate_demo.py
"""
import sys
import joblib
import numpy as np

sys.path.insert(0, "navigation")
sys.path.insert(0, "models")
from astar import FloorGrid, find_path_meters, simplify_path  # noqa: E402
from train_hybrid_model import predict_hybrid  # noqa: E402


def main():
    # Example WiFi reading (feel free to change these three RSSI values)
    ap1, ap2, ap3 = -69, -80, -55  

    grid = FloorGrid(grid_path="floorplan/occupancy_grid.npy",
                      config_path="floorplan/grid_config.json")

    bundle = joblib.load("models/hybrid_model.joblib")
    x, y, zone, used_fallback = predict_hybrid(ap1, ap2, ap3, bundle)
    zone_name = bundle["ap_names"][zone]

    print(f"WiFi reading (AP1={ap1}, AP2={ap2}, AP3={ap3})")
    print(f"  -> roaming zone (strongest AP): {zone_name}{' [fallback model used]' if used_fallback else ''}")
    print(f"  -> predicted position: ({x:.2f}, {y:.2f}) m")

    row, col = grid.meter_to_cell(x, y)
    print(f"  -> walkable at that position? {grid.is_walkable(row, col)}")

    destination = (13.0, 8.0)  # meters - pick any point, e.g. "Room 2 entrance"
    path = find_path_meters(grid, (x, y), destination)
    if path is None:
        print("No path could be found to the destination.")
        return
    waypoints = simplify_path(path)
    print(f"\nPath to destination {destination} ({len(waypoints)} waypoints):")
    for wp in waypoints:
        print(f"  -> ({wp[0]:.2f}, {wp[1]:.2f})")


if __name__ == "__main__":
    main()

