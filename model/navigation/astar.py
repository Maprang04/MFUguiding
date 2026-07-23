"""
astar.py
---------
A* pathfinding over the occupancy grid produced by
floorplan/build_occupancy_grid.py.

This is the "AI navigation" component: given a start and destination in
real-world meters, it finds the shortest walkable path (a list of
waypoints in meters) while avoiding walls/blocked cells.
"""
import heapq
import json
import numpy as np


class FloorGrid:
    def __init__(self, grid_path="../floorplan/occupancy_grid.npy",
                 config_path="../floorplan/grid_config.json"):
        self.grid = np.load(grid_path)          # 0 = walkable, 1 = blocked
        with open(config_path, encoding="utf-8") as config_file:
            cfg = json.load(config_file)
        self.cell_size = cfg["cell_size_m"]
        self.x0, self.x1 = cfg["x_range"]
        self.y0, self.y1 = cfg["y_range"]
        self.n_rows, self.n_cols = self.grid.shape

    def meter_to_cell(self, mx, my):
        col = int((mx - self.x0) / self.cell_size)
        row = int((my - self.y0) / self.cell_size)
        return row, col

    def cell_to_meter(self, row, col):
        mx = self.x0 + (col + 0.5) * self.cell_size
        my = self.y0 + (row + 0.5) * self.cell_size
        return mx, my

    def is_walkable(self, row, col):
        if 0 <= row < self.n_rows and 0 <= col < self.n_cols:
            return self.grid[row, col] == 0
        return False

    def nearest_walkable(self, row, col, max_radius=10):
        """If the requested cell is blocked (e.g. a noisy prediction that
        lands inside a wall), search outward for the closest walkable cell."""
        if self.is_walkable(row, col):
            return row, col
        for r in range(1, max_radius + 1):
            for dr in range(-r, r + 1):
                for dc in range(-r, r + 1):
                    if max(abs(dr), abs(dc)) != r:
                        continue
                    rr, cc = row + dr, col + dc
                    if self.is_walkable(rr, cc):
                        return rr, cc
        raise ValueError("No walkable cell found nearby")


NEIGHBORS_8 = [(-1, 0), (1, 0), (0, -1), (0, 1),
               (-1, -1), (-1, 1), (1, -1), (1, 1)]


def astar(grid: FloorGrid, start_cell, goal_cell):
    """Standard grid A* with 8-connectivity and Euclidean heuristic.
    Returns a list of (row, col) cells from start to goal, or None if
    unreachable."""

    def h(a, b):
        return ((a[0] - b[0]) ** 2 + (a[1] - b[1]) ** 2) ** 0.5

    open_set = [(h(start_cell, goal_cell), 0, start_cell)]
    came_from = {}
    g_score = {start_cell: 0}
    visited = set()

    while open_set:
        _, g, current = heapq.heappop(open_set)
        if current in visited:
            continue
        visited.add(current)

        if current == goal_cell:
            path = [current]
            while current in came_from:
                current = came_from[current]
                path.append(current)
            return path[::-1]

        for dr, dc in NEIGHBORS_8:
            neighbor = (current[0] + dr, current[1] + dc)
            if not grid.is_walkable(*neighbor):
                continue
            # prevent cutting across a diagonal gap between two blocked cells
            if dr != 0 and dc != 0:
                if not grid.is_walkable(current[0] + dr, current[1]) and \
                   not grid.is_walkable(current[0], current[1] + dc):
                    continue
            step_cost = (dr ** 2 + dc ** 2) ** 0.5
            tentative_g = g + step_cost
            if tentative_g < g_score.get(neighbor, float("inf")):
                came_from[neighbor] = current
                g_score[neighbor] = tentative_g
                f = tentative_g + h(neighbor, goal_cell)
                heapq.heappush(open_set, (f, tentative_g, neighbor))

    return None


def find_path_meters(grid: FloorGrid, start_xy, goal_xy):
    """High-level helper: meters in, meters out (list of waypoints)."""
    start_cell = grid.nearest_walkable(*grid.meter_to_cell(*start_xy))
    goal_cell = grid.nearest_walkable(*grid.meter_to_cell(*goal_xy))
    cell_path = astar(grid, start_cell, goal_cell)
    if cell_path is None:
        return None
    return [grid.cell_to_meter(r, c) for r, c in cell_path]


def simplify_path(waypoints, tol=1e-6):
    """Collapse consecutive waypoints that lie on the same straight line,
    so the returned path is a short list of turn points instead of one
    point per grid cell."""
    if len(waypoints) < 3:
        return waypoints
    out = [waypoints[0]]
    for i in range(1, len(waypoints) - 1):
        x0, y0 = out[-1]
        x1, y1 = waypoints[i]
        x2, y2 = waypoints[i + 1]
        d1 = (x1 - x0, y1 - y0)
        d2 = (x2 - x1, y2 - y1)
        cross = d1[0] * d2[1] - d1[1] * d2[0]
        if abs(cross) > tol:
            out.append(waypoints[i])
    out.append(waypoints[-1])
    return out


if __name__ == "__main__":
    grid = FloorGrid()
    path = find_path_meters(grid, (1, 2), (13, 8))
    if path:
        simplified = simplify_path(path)
        print(f"Path found: {len(path)} steps -> {len(simplified)} waypoints after simplification")
        for wp in simplified:
            print(f"  ({wp[0]:.2f}, {wp[1]:.2f})")
    else:
        print("No path found")
