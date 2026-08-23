"""Fine-position inference from simultaneous RSSI readings for AP1-AP3."""

from pathlib import Path

import joblib
import numpy as np


class MultiApPositioner:
    def __init__(self, model_path, calibration=None):
        self.bundle = joblib.load(Path(model_path))
        self.ap_names = list(self.bundle["ap_names"])
        self.calibration = list(calibration or [])

    def predict(self, readings):
        values = [float(readings[name]) for name in self.ap_names]
        nearest = None
        for item in self.calibration:
            reference = [float(item["readings"][name]) for name in self.ap_names]
            rms = float(np.sqrt(np.mean((np.array(values) - np.array(reference)) ** 2)))
            if nearest is None or rms < nearest[0]:
                nearest = (rms, item)
        if nearest is not None:
            rms, item = nearest
            threshold = float(item.get("max_rms_error_db", 6.0))
            if rms <= threshold:
                return {
                    "position": (
                        float(item["position"][0]),
                        float(item["position"][1]),
                    ),
                    "strongest_ap": str(item["zone_ap"]),
                    "radio_strongest_ap": self.ap_names[int(np.argmax(values))],
                    "used_fallback": False,
                    "calibration_used": True,
                    "calibration_id": str(item.get("id", "calibrated-anchor")),
                    "calibration_rms_error_db": rms,
                }
        zone_index = int(np.argmax(values))
        features = np.array([values], dtype=float)
        zone_model = self.bundle["zone_models"].get(zone_index)
        used_fallback = zone_model is None
        selected = zone_model or self.bundle["global"]
        scaled = selected["scaler"].transform(features)
        predicted = selected["model"].predict(scaled)[0]
        return {
            "position": (float(predicted[0]), float(predicted[1])),
            "strongest_ap": self.ap_names[zone_index],
            "radio_strongest_ap": self.ap_names[zone_index],
            "used_fallback": used_fallback,
            "calibration_used": False,
            "calibration_id": None,
            "calibration_rms_error_db": None,
        }
