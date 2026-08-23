"""Inference wrapper for the associated-AP plus RSSI zone model."""

from pathlib import Path

import joblib


class ZoneClassifier:
    def __init__(self, model_path):
        bundle = joblib.load(Path(model_path))
        self.model = bundle["model"]
        self.ap_names = list(bundle["ap_names"])

    def predict(self, associated_ap, median_rssi):
        try:
            ap_index = self.ap_names.index(associated_ap)
        except ValueError as error:
            raise KeyError(f"Unknown AP {associated_ap!r} for zone model") from error
        features = [[ap_index, float(median_rssi)]]
        zone = str(self.model.predict(features)[0])
        probabilities = self.model.predict_proba(features)[0]
        confidence = float(max(probabilities))
        return {"zone": zone, "confidence": confidence}
