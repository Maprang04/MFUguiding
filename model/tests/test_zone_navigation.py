import json
import sys
import unittest
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
sys.path.insert(0, str(ROOT / "navigation"))

from astar import (  # noqa: E402
    FloorGrid,
    find_path_meters,
    route_is_walkable,
    simplify_path,
)
from route_visualizer import RouteVisualizer  # noqa: E402
from positioning.roaming_tracker import RoamingTracker  # noqa: E402
from positioning.rssi_filter import InvalidRssiError, RssiMedianFilter  # noqa: E402
from positioning.zone_estimator import ZoneEstimator  # noqa: E402


class RssiMedianFilterTests(unittest.TestCase):
    def test_median_rejects_single_noise_spike(self):
        filt = RssiMedianFilter(window_size=5)
        values = [-63, -64, -80, -65, -62]
        result = None
        for value in values:
            result = filt.update("user", "AP2", value)
        self.assertEqual(result, -64)

    def test_invalid_rssi_is_rejected(self):
        filt = RssiMedianFilter()
        with self.assertRaises(InvalidRssiError):
            filt.update("user", "AP2", -100)

    def test_ap_windows_are_independent(self):
        filt = RssiMedianFilter(window_size=5)
        filt.update("user", "AP3", -61)
        filt.update("user", "AP3", -63)
        filt.update("user", "AP2", -75)
        self.assertEqual(filt.median("user", "AP3"), -62)
        self.assertEqual(filt.median("user", "AP2"), -75)


class RoamingTrackerTests(unittest.TestCase):
    def test_ap_change_requires_confirmation(self):
        tracker = RoamingTracker(required_confirmations=3)
        self.assertEqual(tracker.update("user", "AP3").current_ap, "AP3")
        self.assertFalse(tracker.update("user", "AP2").roaming_confirmed)
        self.assertFalse(tracker.update("user", "AP2").roaming_confirmed)
        result = tracker.update("user", "AP2")
        self.assertTrue(result.roaming_confirmed)
        self.assertEqual(result.previous_ap, "AP3")
        self.assertEqual(result.current_ap, "AP2")

    def test_ping_pong_does_not_change_current_ap(self):
        tracker = RoamingTracker(required_confirmations=3)
        for ap in ["AP3", "AP2", "AP3", "AP2", "AP3"]:
            result = tracker.update("user", ap)
        self.assertEqual(result.current_ap, "AP3")
        self.assertFalse(result.roaming_confirmed)

    def test_quick_reverse_roam_requires_extra_confirmation(self):
        tracker = RoamingTracker(
            required_confirmations=3,
            reverse_confirmations=5,
            reverse_guard_observations=8,
        )
        tracker.update("user", "AP3")
        tracker.update("user", "AP2")
        tracker.update("user", "AP2")
        self.assertTrue(tracker.update("user", "AP2").roaming_confirmed)

        for _ in range(4):
            result = tracker.update("user", "AP3")
            self.assertFalse(result.roaming_confirmed)
            self.assertEqual(result.current_ap, "AP2")
        result = tracker.update("user", "AP3")
        self.assertTrue(result.roaming_confirmed)
        self.assertEqual(result.current_ap, "AP3")

    def test_reverse_after_guard_uses_normal_confirmation_count(self):
        tracker = RoamingTracker(
            required_confirmations=3,
            reverse_confirmations=5,
            reverse_guard_observations=3,
        )
        tracker.update("user", "AP3")
        tracker.update("user", "AP2")
        tracker.update("user", "AP2")
        self.assertTrue(tracker.update("user", "AP2").roaming_confirmed)
        for _ in range(4):
            tracker.update("user", "AP2")
        self.assertFalse(tracker.update("user", "AP3").roaming_confirmed)
        self.assertFalse(tracker.update("user", "AP3").roaming_confirmed)
        self.assertTrue(tracker.update("user", "AP3").roaming_confirmed)


class ZoneEstimatorTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.config = json.loads((ROOT / "positioning" / "zone_config.json").read_text(encoding="utf-8"))
        cls.estimator = ZoneEstimator(cls.config)

    def test_signal_bands(self):
        self.assertEqual(self.estimator.signal_band(-50), "near")
        self.assertEqual(self.estimator.signal_band(-64), "medium")
        self.assertEqual(self.estimator.signal_band(-78), "edge")

    def test_confirmed_roam_uses_transition_anchor(self):
        result = self.estimator.estimate("AP2", -66, previous_ap="AP3", previous_position=(6, 2))
        self.assertEqual(result["position"], (9.0, 3.5))
        self.assertEqual(result["position_source"], "roaming_transition")
        self.assertEqual(result["confidence"], "high")


class ConfigurationNavigationTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.config = json.loads((ROOT / "positioning" / "zone_config.json").read_text(encoding="utf-8"))
        cls.grid = FloorGrid(
            str(ROOT / "floorplan" / "occupancy_grid.npy"),
            str(ROOT / "floorplan" / "grid_config.json"),
        )

    def test_all_anchors_and_destinations_are_walkable_and_connected(self):
        destinations = [item["position"] for item in self.config["destinations"].values()]
        anchors = []
        for zone in self.config["ap_zones"].values():
            anchors.extend(zone["anchors"].values())
        for candidates in self.config["transitions"].values():
            anchors.extend(candidates)

        for point in anchors + destinations:
            self.assertTrue(self.grid.is_walkable(*self.grid.meter_to_cell(*point)), point)
        for anchor in anchors:
            for destination in destinations:
                self.assertIsNotNone(find_path_meters(self.grid, anchor, destination))

    def test_route_map_can_be_generated(self):
        route = find_path_meters(self.grid, (6.0, 2.0), (15.0, 9.0))
        visualizer = RouteVisualizer(
            ROOT / "floorplan" / "floorplan_clean.png",
            ROOT / "floorplan" / "grid_config.json",
        )
        with tempfile.TemporaryDirectory() as directory:
            output = visualizer.save(route, Path(directory) / "route.png", "Room 2")
            self.assertTrue(output.exists())
            self.assertGreater(output.stat().st_size, 0)

    def test_all_configured_routes_and_simplified_segments_avoid_walls(self):
        destinations = self.config["destinations"].values()
        for ap in self.config["ap_zones"].values():
            for anchor in ap["anchors"].values():
                for destination in destinations:
                    with self.subTest(anchor=anchor, destination=destination["position"]):
                        route = find_path_meters(
                            self.grid, anchor, destination["position"]
                        )
                        self.assertIsNotNone(route)
                        self.assertTrue(route_is_walkable(self.grid, route))
                        simplified = simplify_path(route)
                        self.assertTrue(route_is_walkable(self.grid, simplified))


if __name__ == "__main__":
    unittest.main()
