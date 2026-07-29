import json
from pathlib import Path
import unittest

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]

KNOWN_LOCATIONS = {
    "AP1": (16.25, 11.75),
    "AP2": (10.5, 9.75),
    "AP3": (2.0, 0.5),
    "Room 1 entrance": (15.0, 5.0),
    "Room 2 entrance": (15.0, 9.0),
    "Room 3 entrance": (11.0, 5.0),
}


class FloorPlanCoordinateTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.config = json.loads(
            (ROOT / "floorplan" / "grid_config.json").read_text()
        )
        cls.image = Image.open(ROOT / "floorplan" / "floorplan_clean.png")

    def meter_to_pixel(self, x, y):
        transform = self.config["transform"]
        return (
            transform["a"] * x + transform["b"],
            transform["c"] * y + transform["d"],
        )

    def test_coordinate_convention(self):
        origin_x, origin_y = self.meter_to_pixel(0, 0)
        right_x, _ = self.meter_to_pixel(1, 0)
        _, up_y = self.meter_to_pixel(0, 1)
        self.assertGreater(right_x, origin_x)
        self.assertLess(up_y, origin_y)

    def test_grid_extent_matches_quarter_meter_resolution(self):
        self.assertEqual(self.config["cell_size_m"], 0.25)
        self.assertEqual(self.config["grid_shape"], [48, 92])
        self.assertEqual(self.config["x_range"], [0, 23])
        self.assertEqual(self.config["y_range"], [0, 12])

    def test_all_known_locations_map_inside_floorplan_image(self):
        width, height = self.image.size
        self.assertEqual((width, height), (2048, 1095))
        for label, (x, y) in KNOWN_LOCATIONS.items():
            with self.subTest(label=label):
                pixel_x, pixel_y = self.meter_to_pixel(x, y)
                self.assertGreaterEqual(pixel_x, 0)
                self.assertLessEqual(pixel_x, width)
                self.assertGreaterEqual(pixel_y, 0)
                self.assertLessEqual(pixel_y, height)


if __name__ == "__main__":
    unittest.main()
