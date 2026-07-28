"""Rule-based MVP zone estimator for associated-AP plus one RSSI value."""

import json
import math
from pathlib import Path


def load_zone_config(path):
    with Path(path).open(encoding="utf-8") as stream:
        return json.load(stream)


class ZoneEstimator:
    def __init__(self, config):
        self.config = config

    def signal_band(self, median_rssi):
        thresholds = self.config["rssi"]
        if median_rssi >= thresholds["near_min"]:
            return "near"
        if median_rssi >= thresholds["medium_min"]:
            return "medium"
        return "edge"

    @staticmethod
    def _distance(point_a, point_b):
        return math.hypot(point_a[0] - point_b[0], point_a[1] - point_b[1])

    def _transition_anchor(self, previous_ap, current_ap, previous_position):
        candidates = self.config.get("transitions", {}).get(f"{previous_ap}->{current_ap}")
        if not candidates:
            return None
        if previous_position is None:
            return tuple(candidates[0])
        return tuple(min(candidates, key=lambda point: self._distance(point, previous_position)))

    def estimate(self, current_ap, median_rssi, previous_ap=None, previous_position=None):
        zone_cfg = self.config["ap_zones"].get(current_ap)
        if zone_cfg is None:
            raise KeyError(f"Unknown AP {current_ap!r}; add it to zone_config.json")

        band = self.signal_band(median_rssi)
        transition_anchor = None
        if previous_ap and previous_ap != current_ap:
            transition_anchor = self._transition_anchor(previous_ap, current_ap, previous_position)

        if transition_anchor is not None:
            position = transition_anchor
            source = "roaming_transition"
            confidence = "high"
        else:
            position = tuple(zone_cfg["anchors"][band])
            source = "zone_anchor"
            confidence = "medium" if previous_position is not None else "low"

        return {
            "ap": current_ap,
            "zone": zone_cfg["zone"],
            "label": zone_cfg["label"],
            "signal_band": band,
            "median_rssi": float(median_rssi),
            "position": position,
            "position_source": source,
            "confidence": confidence,
        }

