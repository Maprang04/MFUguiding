"""Rule-based MVP zone estimator for associated-AP plus one RSSI value."""

import json
import math
from pathlib import Path


def load_zone_config(path):
    with Path(path).open(encoding="utf-8") as stream:
        return json.load(stream)


class ZoneEstimator:
    def __init__(self, config, classifier=None):
        self.config = config
        self.classifier = classifier

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

        model_prediction = None
        if self.classifier is not None:
            try:
                model_prediction = self.classifier.predict(current_ap, median_rssi)
            except (KeyError, ValueError):
                # Runtime map data may introduce an AP that was not present in
                # the training snapshot. Keep navigation available via the
                # configured AP-to-zone rule until the model is retrained.
                model_prediction = None
        # A single associated AP is the stable zone boundary. The model is an
        # additional confidence signal, not permission to jump to another zone
        # merely because one RSSI sample crossed a learned threshold.
        model_agrees = (
            model_prediction is not None
            and model_prediction["zone"] == zone_cfg["zone"]
        )

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
            source = "zone_model_band_anchor" if model_prediction else "zone_band_anchor"
            if model_agrees:
                probability = model_prediction["confidence"]
                confidence = "high" if probability >= 0.75 else ("medium" if probability >= 0.55 else "low")
            elif model_prediction:
                confidence = "low"
            else:
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
            "model_confidence": model_prediction["confidence"] if model_prediction else None,
            "zone_model_used": model_prediction is not None,
            "model_agrees_with_ap": model_agrees,
        }

