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

    def test_destination_change_recalculates_existing_route(self):
        self.service.submit_observation("nav-test", "AP3", -62)
        changed = self.service.change_destination("nav-test", "room_2")
        self.assertEqual(changed["destination_id"], "room_2")
        self.assertGreater(len(changed["route"]), 1)

    def test_deleted_session_is_not_available(self):
        self.service.delete_session("nav-test")
        with self.assertRaises(PositioningError) as context:
            self.service.get_session("nav-test")
        self.assertEqual(context.exception.code, "SESSION_NOT_FOUND")

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
