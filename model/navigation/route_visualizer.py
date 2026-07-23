"""Draw navigation routes on the calibrated floor-plan image."""

import json
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


class RouteVisualizer:
    def __init__(self, floorplan_path, grid_config_path):
        self.floorplan_path = Path(floorplan_path)
        with Path(grid_config_path).open(encoding="utf-8") as stream:
            self.config = json.load(stream)
        self.transform = self.config["transform"]

    def meter_to_pixel(self, x, y):
        transform = self.transform
        return (
            transform["a"] * x + transform["b"],
            transform["c"] * y + transform["d"],
        )

    @staticmethod
    def _draw_marker(draw, point, fill, label):
        x, y = point
        radius = 14
        draw.ellipse((x - radius, y - radius, x + radius, y + radius), fill=fill, outline=(255, 255, 255), width=4)
        font = ImageFont.load_default(size=20)
        draw.text((x + 18, y - 25), label, fill=fill, stroke_width=3, stroke_fill=(255, 255, 255), font=font)

    def save(self, route, output_path, destination_label="Destination"):
        if not route:
            raise ValueError("route must contain at least one waypoint")
        image = Image.open(self.floorplan_path).convert("RGB")
        draw = ImageDraw.Draw(image)
        pixels = [self.meter_to_pixel(x, y) for x, y in route]

        if len(pixels) > 1:
            # A light outline preserves route visibility over walls and labels.
            draw.line(pixels, fill=(255, 255, 255), width=18, joint="curve")
            draw.line(pixels, fill=(0, 102, 255), width=10, joint="curve")
        for point in pixels[1:-1]:
            x, y = point
            draw.ellipse((x - 5, y - 5, x + 5, y + 5), fill=(0, 102, 255))

        self._draw_marker(draw, pixels[0], (0, 145, 80), "START")
        self._draw_marker(draw, pixels[-1], (210, 35, 45), destination_label)

        output_path = Path(output_path)
        output_path.parent.mkdir(parents=True, exist_ok=True)
        image.save(output_path)
        return output_path

