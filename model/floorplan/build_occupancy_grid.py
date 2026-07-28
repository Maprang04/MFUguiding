"""
build_occupancy_grid.py
------------------------
Builds a real-world (meters) occupancy grid from the floor-plan drawing.

How the calibration works
==========================
`floorplan_with_grid_ref.png` has 8 red reference dots drawn on it whose
real-world coordinates we already know (they are the same points used to
collect the WiFi fingerprints: (1,2) (5,2) (9,2) (13,2) (13,4) (13,8)
(16,3.75) (19,3.75)).

We auto-detect the pixel location of those 8 dots (connected-component
blob detection on the red channel) and fit a simple linear
pixel <-> meter transform for X and Y independently:

    px = a * mx + b
    py = c * my + d

Once we have that transform we can:
  1. Load the CLEAN floor plan (`floorplan_clean.png`, no red overlay)
  2. Detect wall pixels (near-black, thick lines -> walls / structure)
  3. Rasterize a grid in meter-space (default 0.25 m cells). A cell is
     marked WALKABLE (0) unless a large enough fraction of its pixels
     are wall pixels, in which case it's NON-WALKABLE (1).

Output:
  - occupancy_grid.npy   -> 2D uint8 array, 0 = walkable, 1 = blocked
  - grid_config.json     -> transform + grid metadata (needed to convert
                             between meter coordinates and grid indices)
  - occupancy_overlay.png -> visualization for sanity-checking alignment
"""
import json
import numpy as np
from PIL import Image
from scipy import ndimage

REF_IMG = "floorplan_with_grid_ref.png"
CLEAN_IMG = "floorplan_clean.png"
CELL_SIZE_M = 0.25          # resolution of the navigation grid
WALL_GRAY_THRESHOLD = 50    # pixel is "wall" if grayscale value < this
WALL_FRACTION_THRESHOLD = 0.12  # cell is blocked if >=12% of its pixels are wall

# The diagonally-hatched zone (top-left of the plan) has no room label in
# the reference drawing and, per standard floor-plan convention, hatching
# denotes solid/inaccessible structure (e.g. a shaft, void, or masonry
# core) rather than a walkable room. Because the hatch lines are thin and
# sparse, plain pixel-density wall detection under-detects this zone, so
# we explicitly blank it out as a manually-calibrated exclusion box
# (x_min, x_max, y_min, y_max) in meters. Adjust/remove this if your own
# floor plan's hatching means something else (e.g. a walkable stairwell).
HATCHED_EXCLUSION_BOX_M = (0.0, 4.6, 4.15, 11.95)


# Real-world coordinates of the known reference dots (must match the
# red dots baked into floorplan_with_grid_ref.png / the wifi_dataset points)
KNOWN_METERS = [
    (1, 2), (5, 2), (9, 2), (13, 2),
    (13, 4), (13, 8), (16, 3.75), (19, 3.75),
]


def detect_reference_dots(img_path):
    """Find the pixel centers of the round red reference dots (not the
    thin grid lines and not the red text labels)."""
    im = np.array(Image.open(img_path).convert("RGB"))
    r, g, b = im[:, :, 0].astype(int), im[:, :, 1].astype(int), im[:, :, 2].astype(int)
    red_mask = (r > 150) & (g < 100) & (b < 100)

    lbl, n = ndimage.label(red_mask, structure=np.ones((3, 3)))
    objs = ndimage.find_objects(lbl)
    dots = []
    for i, sl in enumerate(objs):
        h = sl[0].stop - sl[0].start
        w = sl[1].stop - sl[1].start
        area = int((lbl[sl] == (i + 1)).sum())
        # Dots are roughly circular blobs ~28-33px across; text/grid-line
        # fragments are either much thinner or much more elongated.
        if 24 <= w <= 36 and 24 <= h <= 36 and area > 550:
            cy = (sl[0].start + sl[0].stop) / 2
            cx = (sl[1].start + sl[1].stop) / 2
            dots.append((cx, cy))
    return dots


def match_dots_to_meters(dots, known_meters):
    """Greedy-match detected pixel dots to the known meter coordinates
    using their known relative layout (sorted by y row, then x)."""
    # sort dots top-to-bottom (increasing pixel y = decreasing meter y),
    # matching sorted(known_meters) by descending y then x won't be robust
    # generically, so instead we match by nearest-neighbour on a rough
    # initial affine guess built from min/max spread.
    dots = np.array(dots)
    km = np.array(known_meters, dtype=float)

    # rough scale/offset guess from bounding boxes
    px_min, px_max = dots[:, 0].min(), dots[:, 0].max()
    py_min, py_max = dots[:, 1].min(), dots[:, 1].max()
    mx_min, mx_max = km[:, 0].min(), km[:, 0].max()
    my_min, my_max = km[:, 1].min(), km[:, 1].max()

    def guess_px(mx):
        return px_min + (mx - mx_min) / (mx_max - mx_min) * (px_max - px_min)

    def guess_py(my):
        # image y grows downward, meter y grows upward -> invert
        return py_max - (my - my_min) / (my_max - my_min) * (py_max - py_min)

    guessed = np.array([[guess_px(mx), guess_py(my)] for mx, my in km])

    # match each guessed point to nearest actual detected dot
    matches = []
    used = set()
    for i, g in enumerate(guessed):
        d = np.linalg.norm(dots - g, axis=1)
        order = np.argsort(d)
        for j in order:
            if j not in used:
                used.add(j)
                matches.append((dots[j, 0], dots[j, 1], km[i, 0], km[i, 1]))
                break
    return matches


def fit_transform(matches):
    matches = np.array(matches)
    px, py, mx, my = matches[:, 0], matches[:, 1], matches[:, 2], matches[:, 3]
    A = np.vstack([mx, np.ones_like(mx)]).T
    a, b = np.linalg.lstsq(A, px, rcond=None)[0]
    A2 = np.vstack([my, np.ones_like(my)]).T
    c, d = np.linalg.lstsq(A2, py, rcond=None)[0]
    resid_px = np.abs(px - (a * mx + b)).max()
    resid_py = np.abs(py - (c * my + d)).max()
    print(f"[calibration] px = {a:.4f}*mx + {b:.4f}   (max resid {resid_px:.2f}px)")
    print(f"[calibration] py = {c:.4f}*my + {d:.4f}   (max resid {resid_py:.2f}px)")
    return dict(a=a, b=b, c=c, d=d)


def meter_to_px(mx, my, t):
    return t["a"] * mx + t["b"], t["c"] * my + t["d"]


def build_wall_mask(img_path):
    im = np.array(Image.open(img_path).convert("RGB"))
    gray = im.mean(axis=2)
    return gray < WALL_GRAY_THRESHOLD


def rasterize_grid(wall_mask, t, x_range, y_range, cell_size):
    h, w = wall_mask.shape
    xs = np.arange(x_range[0], x_range[1], cell_size)
    ys = np.arange(y_range[0], y_range[1], cell_size)
    grid = np.zeros((len(ys), len(xs)), dtype=np.uint8)  # rows=y, cols=x

    for iy, my in enumerate(ys):
        for ix, mx in enumerate(xs):
            # bounding box of this cell in meters -> pixels
            px0, py0 = meter_to_px(mx, my + cell_size, t)          # top-left (higher my = higher up = smaller py)
            px1, py1 = meter_to_px(mx + cell_size, my, t)          # bottom-right
            x0, x1 = sorted((int(round(px0)), int(round(px1))))
            y0, y1 = sorted((int(round(py0)), int(round(py1))))
            x0, y0 = max(x0, 0), max(y0, 0)
            x1, y1 = min(x1, w), min(y1, h)
            if x1 <= x0 or y1 <= y0:
                grid[iy, ix] = 1  # out of image bounds -> treat as blocked
                continue
            patch = wall_mask[y0:y1, x0:x1]
            frac = patch.mean() if patch.size else 1.0
            grid[iy, ix] = 1 if frac >= WALL_FRACTION_THRESHOLD else 0
    return grid, xs, ys


def save_overlay(clean_img_path, wall_mask, grid, xs, ys, t, out_path):
    base = Image.open(clean_img_path).convert("RGB")
    overlay = np.array(base).copy()
    red = np.array([255, 0, 0])
    for iy, my in enumerate(ys):
        for ix, mx in enumerate(xs):
            if grid[iy, ix] == 1:
                px0, py0 = meter_to_px(mx, my + CELL_SIZE_M, t)
                px1, py1 = meter_to_px(mx + CELL_SIZE_M, my, t)
                x0, x1 = sorted((int(px0), int(px1)))
                y0, y1 = sorted((int(py0), int(py1)))
                x0, y0 = max(x0, 0), max(y0, 0)
                x1, y1 = min(x1, overlay.shape[1]), min(y1, overlay.shape[0])
                overlay[y0:y1, x0:x1] = (overlay[y0:y1, x0:x1] * 0.5 + red * 0.5).astype(np.uint8)
    Image.fromarray(overlay).save(out_path)


def main():
    dots = detect_reference_dots(REF_IMG)
    print(f"Detected {len(dots)} candidate reference dots")
    matches = match_dots_to_meters(dots, KNOWN_METERS)
    t = fit_transform(matches)

    wall_mask = build_wall_mask(CLEAN_IMG)

    # meter extents to rasterize (covers the whole drawn floor plan with margin)
    x_range = (0, 23)
    y_range = (0, 12)

    grid, xs, ys = rasterize_grid(wall_mask, t, x_range, y_range, CELL_SIZE_M)

    # apply the manual hatched-zone exclusion override
    hx0, hx1, hy0, hy1 = HATCHED_EXCLUSION_BOX_M
    for iy, my in enumerate(ys):
        if not (hy0 <= my < hy1):
            continue
        for ix, mx in enumerate(xs):
            if hx0 <= mx < hx1:
                grid[iy, ix] = 1

    print(f"Grid shape (rows=y, cols=x): {grid.shape}, walkable cells: {(grid==0).sum()}, blocked: {(grid==1).sum()}")

    np.save("occupancy_grid.npy", grid)
    save_overlay(CLEAN_IMG, wall_mask, grid, xs, ys, t, "occupancy_overlay.png")

    config = {
        "transform": t,
        "cell_size_m": CELL_SIZE_M,
        "x_range": x_range,
        "y_range": y_range,
        "grid_shape": list(grid.shape),
        "note": "grid[row, col] where row corresponds to y_range[0] + row*cell_size, col to x_range[0] + col*cell_size. 0=walkable, 1=blocked.",
    }
    with open("grid_config.json", "w") as f:
        json.dump(config, f, indent=2)
    print("Saved occupancy_grid.npy, grid_config.json, occupancy_overlay.png")


if __name__ == "__main__":
    main()
