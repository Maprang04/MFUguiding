"""Train a coarse zone classifier from the existing Wi-Fi fingerprints.

Runtime features intentionally match what the Android application can read:
the currently associated AP and its median RSSI.
"""

from __future__ import annotations

import json
from pathlib import Path

import joblib
import numpy as np
import pandas as pd
from sklearn.ensemble import RandomForestClassifier
from sklearn.model_selection import StratifiedKFold, cross_val_score


ROOT = Path(__file__).resolve().parents[1]
DATASET = ROOT / "data" / "wifi_dataset.csv"
OUTPUT = Path(__file__).resolve().parent / "zone_classifier.joblib"
REPORT = Path(__file__).resolve().parent / "zone_classifier_report.json"
AP_COLUMNS = ["ap1", "ap2", "ap3"]
AP_NAMES = ["AP1", "AP2", "AP3"]


def zone_from_x(x: float) -> str:
    if x < 9:
        return "LEFT_WING"
    if x < 15:
        return "CENTRAL_HALLWAY"
    return "RIGHT_WING"


def prepare(df: pd.DataFrame):
    readings = df[AP_COLUMNS].to_numpy(dtype=float)
    associated_indexes = readings.argmax(axis=1)
    associated_rssi = readings[np.arange(len(readings)), associated_indexes]
    features = np.column_stack([associated_indexes, associated_rssi])
    labels = df["x"].astype(float).map(zone_from_x).to_numpy()
    return features, labels


def main():
    df = pd.read_csv(DATASET)
    features, labels = prepare(df)
    model = RandomForestClassifier(
        n_estimators=300,
        max_depth=8,
        min_samples_leaf=2,
        class_weight="balanced",
        random_state=42,
    )
    folds = min(5, int(pd.Series(labels).value_counts().min()))
    scores = cross_val_score(
        model,
        features,
        labels,
        cv=StratifiedKFold(n_splits=folds, shuffle=True, random_state=42),
        scoring="accuracy",
    )
    model.fit(features, labels)
    joblib.dump(
        {
            "model": model,
            "ap_names": AP_NAMES,
            "features": ["associated_ap_index", "median_rssi"],
            "zones": sorted(set(labels)),
        },
        OUTPUT,
    )
    report = {
        "samples": int(len(labels)),
        "class_counts": pd.Series(labels).value_counts().sort_index().to_dict(),
        "cross_validation_accuracy_mean": float(scores.mean()),
        "cross_validation_accuracy_std": float(scores.std()),
        "features": ["associated_ap", "median_rssi"],
        "note": "Zone labels are derived from existing fingerprint x coordinates; no new collection was used.",
    }
    REPORT.write_text(json.dumps(report, indent=2), encoding="utf-8")
    print(json.dumps(report, indent=2))


if __name__ == "__main__":
    main()
