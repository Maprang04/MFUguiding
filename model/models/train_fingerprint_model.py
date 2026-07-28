"""
train_fingerprint_model.py
----------------------------
Trains a WiFi-fingerprinting position model:

    input  : RSSI readings to AP1, AP2, AP3 (dBm, e.g. -82, -81, -58)
    output : (x, y) position in meters on the floor plan

Why KNN?
    With only ~79 samples spread across 8 physical reference points, this is
    a classic small fingerprint database. K-Nearest-Neighbours in RSSI-space
    is the standard, well-proven baseline for this problem (it is literally
    how commercial "WiFi fingerprinting" positioning works) and does not
    overfit the way a deep model would on this little data. We also train a
    Random Forest as a comparison baseline.

Outputs (saved into ../models/):
    fingerprint_knn.joblib        - trained KNN regressor + scaler
    fingerprint_rf.joblib         - trained Random Forest regressor
    training_report.json         - cross-validated error metrics
"""
import sys
import os
import json
import numpy as np
import pandas as pd
from sklearn.neighbors import KNeighborsRegressor
from sklearn.ensemble import RandomForestRegressor
from sklearn.preprocessing import StandardScaler
from sklearn.model_selection import KFold
from sklearn.metrics import mean_absolute_error
import joblib

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "data"))
from load_data import load_wifi_dataset  # noqa: E402


def load_data():
    df = load_wifi_dataset()
    X = df[["ap1", "ap2", "ap3"]].values.astype(float)
    y = df[["x", "y"]].values.astype(float)
    return df, X, y


def positional_error(y_true, y_pred):
    """Mean Euclidean distance error in meters."""
    return float(np.mean(np.linalg.norm(y_true - y_pred, axis=1)))


def cross_validate(model_fn, X, y, n_splits=5, seed=42):
    kf = KFold(n_splits=n_splits, shuffle=True, random_state=seed)
    errors = []
    for train_idx, test_idx in kf.split(X):
        scaler = StandardScaler().fit(X[train_idx])
        Xtr, Xte = scaler.transform(X[train_idx]), scaler.transform(X[test_idx])
        model = model_fn()
        model.fit(Xtr, y[train_idx])
        pred = model.predict(Xte)
        errors.append(positional_error(y[test_idx], pred))
    return float(np.mean(errors)), float(np.std(errors))


def main():
    df, X, y = load_data()
    print(f"Loaded {len(df)} fingerprint samples across {len(df[['x','y']].drop_duplicates())} unique locations")

    # ---- cross-validated comparison ----
    knn_mean, knn_std = cross_validate(lambda: KNeighborsRegressor(n_neighbors=3, weights="distance"), X, y)
    rf_mean, rf_std = cross_validate(lambda: RandomForestRegressor(n_estimators=200, random_state=42), X, y)
    print(f"KNN  (k=3, distance-weighted): mean positional error = {knn_mean:.2f} m (+/- {knn_std:.2f})")
    print(f"RandomForest (200 trees)     : mean positional error = {rf_mean:.2f} m (+/- {rf_std:.2f})")

    # ---- try a few k values for KNN to pick the best ----
    k_results = {}
    for k in [1, 2, 3, 4, 5]:
        m, s = cross_validate(lambda k=k: KNeighborsRegressor(n_neighbors=k, weights="distance"), X, y)
        k_results[k] = m
        print(f"  KNN k={k}: {m:.2f} m")
    best_k = min(k_results, key=k_results.get)
    print(f"Best k = {best_k}")

    # ---- final fit on ALL data ----
    scaler = StandardScaler().fit(X)
    Xs = scaler.transform(X)

    knn_final = KNeighborsRegressor(n_neighbors=best_k, weights="distance").fit(Xs, y)
    rf_final = RandomForestRegressor(n_estimators=200, random_state=42).fit(Xs, y)

    joblib.dump({"model": knn_final, "scaler": scaler, "k": best_k}, "fingerprint_knn.joblib")
    joblib.dump({"model": rf_final, "scaler": scaler}, "fingerprint_rf.joblib")

    report = {
        "n_samples": int(len(df)),
        "n_unique_locations": int(len(df[["x", "y"]].drop_duplicates())),
        "knn_best_k": best_k,
        "knn_cv_mean_error_m": knn_mean,
        "knn_cv_std_error_m": knn_std,
        "rf_cv_mean_error_m": rf_mean,
        "rf_cv_std_error_m": rf_std,
        "recommended_model": "fingerprint_knn.joblib" if knn_mean <= rf_mean else "fingerprint_rf.joblib",
        "note": (
            "Errors are cross-validated mean Euclidean distance (meters) between "
            "predicted and true position. With only 8 reference points, this model "
            "can reliably say 'you are closest to reference point X' but has no data "
            "to interpolate positions BETWEEN reference points confidently. Collect "
            "more reference points (denser grid) to improve resolution."
        ),
    }
    with open("training_report.json", "w") as f:
        json.dump(report, f, indent=2)
    print("Saved fingerprint_knn.joblib, fingerprint_rf.joblib, training_report.json")


if __name__ == "__main__":
    main()
