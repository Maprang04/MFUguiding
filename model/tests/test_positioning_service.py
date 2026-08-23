import unittest

from positioning.service import PositioningError, PositioningService


class PositioningServiceTests(unittest.TestCase):
    def setUp(self):
        self.service = PositioningService()
        self.service.create_session("nav-test", "phone-1", "room_3")

    def test_first_observation_returns_position_and_route(self):
        result = self.service.submit_observation("nav-test", "AP3", -62)
        self.assertEqual(result["confirmed_ap"], "AP3")
        self.assertTrue(result["route_recalculated"])
        self.assertGreater(len(result["route"]), 1)

    def test_three_ap_fingerprint_refines_position_inside_confirmed_zone(self):
        self.service.config["positioning"]["stable_zone_navigation"] = False
        result = self.service.submit_observation(
            "nav-test",
            "AP3",
            -50,
            {"AP1": -82, "AP2": -75, "AP3": -50},
        )
        self.assertTrue(result["multi_ap_used"])
        self.assertEqual(result["multi_ap_strongest_ap"], "AP3")
        self.assertEqual(result["position_source"], "three_ap_fingerprint")
        self.assertTrue(result["route_recalculated"])

    def test_three_ap_scan_can_override_sticky_connected_ap_zone(self):
        self.service.config["positioning"]["stable_zone_navigation"] = False
        readings = {"AP1": -45, "AP2": -75, "AP3": -62}
        first = self.service.submit_observation("nav-test", "AP3", -62, readings)
        second = self.service.submit_observation("nav-test", "AP3", -62, readings)
        result = self.service.submit_observation("nav-test", "AP3", -62, readings)
        self.assertFalse(first["multi_ap_used"])
        self.assertFalse(second["multi_ap_used"])
        self.assertTrue(result["multi_ap_used"])
        self.assertEqual(result["confirmed_ap"], "AP3")
        self.assertEqual(result["multi_ap_strongest_ap"], "AP1")
        self.assertEqual(result["position_source"], "three_ap_fingerprint")
        self.assertEqual(result["zone"], "RIGHT_WING")

    def test_transient_fingerprint_spike_does_not_change_zone(self):
        self.service.config["positioning"]["stable_zone_navigation"] = False
        stable = {"AP1": -82, "AP2": -75, "AP3": -50}
        spike = {"AP1": -45, "AP2": -75, "AP3": -62}
        self.service.submit_observation("nav-test", "AP3", -50, stable)
        result = self.service.submit_observation("nav-test", "AP3", -62, spike)
        self.assertEqual(result["fingerprint_ap"], "AP3")
        self.assertIsNone(result["candidate_fingerprint_ap"])
        self.assertEqual(result["candidate_fingerprint_count"], 0)
        self.assertTrue(result["fingerprint_zone_confirmed"])
        self.assertEqual(result["zone"], "LEFT_WING")

    def test_arrival_guard_requires_stable_destination_evidence(self):
        self.service.config["positioning"]["stable_zone_navigation"] = False
        class DestinationPositioner:
            ap_names = ["AP1", "AP2", "AP3"]

            @staticmethod
            def predict(_readings):
                return {
                    "position": (15.0, 5.0),
                    "strongest_ap": "AP1",
                    "used_fallback": False,
                }

        self.service.delete_session("nav-test")
        self.service.create_session(
            "nav-arrival", "phone-arrival", "room_1", {"x": 11, "y": 5}
        )
        self.service.multi_ap_positioner = DestinationPositioner()
        readings = {"AP1": -45, "AP2": -70, "AP3": -80}
        held = []
        for _ in range(2):
            held.append(
                self.service.submit_observation(
                    "nav-arrival", "AP1", -45, readings
                )
            )
        self.assertTrue(all(item["arrival_guard_active"] for item in held))
        self.assertTrue(all(item["estimated_position"] == {"x": 11.125, "y": 5.125} for item in held))
        released = self.service.submit_observation(
            "nav-arrival", "AP1", -45, readings
        )
        self.assertFalse(released["arrival_guard_active"])
        self.assertTrue(released["multi_ap_used"])
        self.assertNotEqual(released["estimated_position"], held[-1]["estimated_position"])

    def test_fingerprint_noise_cannot_move_marker_backward_on_route(self):
        self.service.config["positioning"]["stable_zone_navigation"] = False
        class SequencePositioner:
            ap_names = ["AP1", "AP2", "AP3"]

            def __init__(self):
                self.positions = [(12.0, 5.0), (11.25, 5.0)]

            def predict(self, _readings):
                return {
                    "position": self.positions.pop(0),
                    "strongest_ap": "AP2",
                    "used_fallback": False,
                }

        self.service.delete_session("nav-test")
        self.service.create_session(
            "nav-forward", "phone-forward", "room_1", {"x": 11, "y": 5}
        )
        self.service.multi_ap_positioner = SequencePositioner()
        readings = {"AP1": -70, "AP2": -45, "AP3": -80}
        forward = self.service.submit_observation(
            "nav-forward", "AP2", -45, readings
        )
        backward_noise = self.service.submit_observation(
            "nav-forward", "AP2", -45, readings
        )
        self.assertGreaterEqual(
            backward_noise["estimated_position"]["x"],
            forward["estimated_position"]["x"],
        )

    def test_roaming_requires_three_consecutive_observations(self):
        self.service.submit_observation("nav-test", "AP3", -62)
        first = self.service.submit_observation("nav-test", "AP2", -72)
        second = self.service.submit_observation("nav-test", "AP2", -68)
        third = self.service.submit_observation("nav-test", "AP2", -65)
        self.assertEqual(first["candidate_count"], 1)
        self.assertEqual(second["candidate_count"], 2)
        self.assertFalse(second["roaming_confirmed"])
        self.assertTrue(third["roaming_confirmed"])
        self.assertEqual(third["confirmed_ap"], "AP2")

    def test_stable_zone_mode_locks_position_until_roaming_is_confirmed(self):
        self.service.config["positioning"]["stable_zone_navigation"] = True
        initial = self.service.submit_observation("nav-test", "AP3", -52)
        locked_position = initial["estimated_position"]
        for noisy_rssi in (-69, -48, -78, -55):
            result = self.service.submit_observation(
                "nav-test",
                "AP3",
                noisy_rssi,
                {"AP1": -62, "AP2": -65, "AP3": noisy_rssi},
            )
            self.assertEqual(result["confirmed_ap"], "AP3")
            self.assertEqual(result["estimated_position"], locked_position)
            self.assertEqual(result["position_source"], "stable_zone_lock")
            self.assertFalse(result["route_recalculated"])

        self.service.submit_observation("nav-test", "AP2", -62)
        self.service.submit_observation("nav-test", "AP2", -62)
        roamed = self.service.submit_observation("nav-test", "AP2", -62)
        self.assertTrue(roamed["roaming_confirmed"])
        self.assertNotEqual(roamed["estimated_position"], locked_position)
        self.assertTrue(roamed["route_recalculated"])

    def test_destination_change_recalculates_existing_route(self):
        self.service.submit_observation("nav-test", "AP3", -62)
        changed = self.service.change_destination("nav-test", "room_2")
        self.assertEqual(changed["destination_id"], "room_2")
        self.assertGreater(len(changed["route"]), 1)

    def test_rssi_band_requires_confirmation_before_refining_position(self):
        self.service.config["positioning"]["stable_zone_navigation"] = False
        initial = self.service.submit_observation("nav-test", "AP3", -78)
        before = initial["estimated_position"]

        self.service.submit_observation("nav-test", "AP3", -50)
        self.service.submit_observation("nav-test", "AP3", -50)
        second_near = self.service.submit_observation("nav-test", "AP3", -50)
        self.assertEqual(second_near["estimated_position"], before)
        self.assertFalse(second_near["band_position_confirmed"])

        confirmed = self.service.submit_observation("nav-test", "AP3", -50)
        self.assertTrue(confirmed["band_position_confirmed"])
        self.assertNotEqual(confirmed["estimated_position"], before)
        self.assertEqual(confirmed["position_band"], "near")
        self.assertEqual(confirmed["position_source"], "stable_rssi_band_anchor")
        self.assertTrue(confirmed["route_recalculated"])

    def test_deleted_session_is_not_available(self):
        self.service.delete_session("nav-test")
        with self.assertRaises(PositioningError) as context:
            self.service.get_session("nav-test")
        self.assertEqual(context.exception.code, "SESSION_NOT_FOUND")

    def test_selected_start_and_steps_advance_along_route(self):
        self.service.delete_session("nav-test")
        created = self.service.create_session(
            "nav-steps", "phone-steps", "room_1", {"x": 11, "y": 5}
        )
        self.assertIsNotNone(created["estimated_position"])
        before = created["estimated_position"]
        progressed = self.service.advance_progress("nav-steps", 1.3)
        after = progressed["estimated_position"]
        self.assertNotEqual(before, after)
        self.assertAlmostEqual(progressed["distance_delta"], 1.3, places=4)
        self.assertEqual(progressed["position_source"], "step_route_progress")
        self.assertEqual(progressed["route"][0], after)

    def test_mongodb_snapshot_can_replace_runtime_catalog(self):
        self.service.delete_session("nav-test")
        result = self.service.configure(
            {
                "destinations": [
                    {
                        "id": "room_db",
                        "label": "Database room",
                        "position": {"x": 15, "y": 5},
                    }
                ],
                "access_points": [
                    {
                        "name": "AP_DB",
                        "zone": "DATABASE_ZONE",
                        "zoneLabel": "Database zone",
                        "anchors": {
                            "near": {"x": 15, "y": 5},
                            "medium": {"x": 14, "y": 4},
                            "edge": {"x": 13, "y": 3},
                        },
                    }
                ],
                "transitions": {},
            }
        )
        self.assertTrue(result["configured"])
        self.service.create_session("nav-db", "phone-db", "room_db")
        position = self.service.submit_observation("nav-db", "AP_DB", -60)
        self.assertEqual(position["zone"], "DATABASE_ZONE")


if __name__ == "__main__":
    unittest.main()
