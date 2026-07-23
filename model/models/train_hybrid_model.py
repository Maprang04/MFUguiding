"""
train_hybrid_model.py
-----------------------
Hybrid positioning model combining two signals, per the professor's
requested design:

  1. "Roaming" zone - which AP the phone would actually associate/roam to
     (simulated here as the AP with the strongest RSSI in a reading -
     this is exactly what real WiFi roaming decisions are based on).
     This gives a coarse, very robust "which part of the building" signal
     -- it doesn't depend on precise RSSI-to-distance calibration at all,
     just on which of the 3 numbers is the largest (least negative).

  2. RSSI fingerprinting (KNN) - refines the position WITHIN that zone
     using all 3 AP readings together, the same approach used in
     train_fingerprint_model.py.

Why combine them:
  - The zone step acts as a coarse, very robust classifier (hard to get
    wrong even with noisy readings) and constrains the fine-grained KNN
    search to physically plausible neighbours only, instead of letting a
    single noisy reading get "pulled" toward a distant reference point
    that happens to look similar in RSSI-space.
  - It also mirrors how you'd scale this to multiple floors/wings later:
    zone (roaming AP / floor) narrows things down first, then a
    per-zone fingerprint model gives the precise (x, y).

Output (saved into ../models/):
  hybrid_model.joblib      - per-zone KNN models + a global fallback model
  hybrid_training_report.json
"""
import sys
import os
import json
import numpy as np
import pandas as pd
from sklearn.neighbors import KNeighborsRegressor
from sklearn.preprocessing import StandardScaler
from sklearn.model_selection import KFold
import joblib

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "data"))
from load_data import load_wifi_dataset  # noqa: E402

AP_COLS = ["ap1", "ap2", "ap3"]
MIN_SAMPLES_PER_ZONE = 8  # below this, fall back to the global model for that zone


def load_data():
    df = load_wifi_dataset()
    df["zone_ap"] = df[AP_COLS].values.argmax(axis=1)  # 0=ap1, 1=ap2, 2=ap3 (strongest signal)
    return df


def positional_error(y_true, y_pred):
    return float(np.mean(np.linalg.norm(y_true - y_pred, axis=1)))


def predict_hybrid(ap1, ap2, ap3, bundle):
    """Given a raw RSSI reading, return (x, y, zone, used_fallback)."""
    zone = int(np.argmax([ap1, ap2, ap3]))
    X = np.array([[ap1, ap2, ap3]], dtype=float)

    zone_model = bundle["zone_models"].get(zone)
    if zone_model is not None:
        Xs = zone_model["scaler"].transform(X)
        pred = zone_model["model"].predict(Xs)[0]
        return float(pred[0]), float(pred[1]), zone, False

    # fallback: global model (used when a zone has too few training samples)
    Xs = bundle["global"]["scaler"].transform(X)
    pred = bundle["global"]["model"].predict(Xs)[0]
    return float(pred[0]), float(pred[1]), zone, True


def cross_validate_hybrid(df, n_splits=5, seed=42, k=1):
    """Cross-validate the hybrid (zone-restricted KNN) approach."""
    kf = KFold(n_splits=n_splits, shuffle=True, random_state=seed)
    X_all = df[AP_COLS].values.astype(float)
    y_all = df[["x", "y"]].values.astype(float)
    zones_all = df["zone_ap"].values

    errors = []
    for train_idx, test_idx in kf.split(X_all):
        # build per-zone models from this fold's training data only
        zone_models = {}
        for z in np.unique(zones_all[train_idx]):
            mask = zones_all[train_idx] == z
            if mask.sum() < MIN_SAMPLES_PER_ZONE:
                continue
            Xz, yz = X_all[train_idx][mask], y_all[train_idx][mask]
            scaler = StandardScaler().fit(Xz)
            model = KNeighborsRegressor(n_neighbors=min(k, len(Xz)), weights="distance").fit(scaler.transform(Xz), yz)
            zone_models[z] = {"model": model, "scaler": scaler}

        global_scaler = StandardScaler().fit(X_all[train_idx])
        global_model = KNeighborsRegressor(n_neighbors=k, weights="distance").fit(
            global_scaler.transform(X_all[train_idx]), y_all[train_idx])
        bundle = {"zone_models": zone_models, "global": {"model": global_model, "scaler": global_scaler}}

        preds = []
        for i in test_idx:
            x, y, _, _ = predict_hybrid(*X_all[i], bundle)
            preds.append([x, y])
        errors.append(positional_error(y_all[test_idx], np.array(preds)))

    return float(np.mean(errors)), float(np.std(errors))


def main():
    df = load_data()
    print(f"Loaded {len(df)} samples. Zone (strongest-AP) distribution:")
    print(df["zone_ap"].map({0: "AP1", 1: "AP2", 2: "AP3"}).value_counts())

    # search a few k values for the zone-restricted KNN and keep the best
    k_results = {}
    for k in [1, 2, 3, 4, 5]:
        m, s = cross_validate_hybrid(df, k=k)
        k_results[k] = m
        print(f"  hybrid k={k}: {m:.2f} m (+/- {s:.2f})")
    best_k = min(k_results, key=k_results.get)
    hybrid_mean = k_results[best_k]
    print(f"Best k = {best_k} -> mean positional error = {hybrid_mean:.2f} m")

    # ---- fit final model on all data ----
    X_all = df[AP_COLS].values.astype(float)
    y_all = df[["x", "y"]].values.astype(float)
    zones_all = df["zone_ap"].values

    zone_models = {}
    for z in np.unique(zones_all):
        mask = zones_all == z
        if mask.sum() < MIN_SAMPLES_PER_ZONE:
            print(f"  zone {z}: only {mask.sum()} samples -> will use global fallback")
            continue
        Xz, yz = X_all[mask], y_all[mask]
        scaler = StandardScaler().fit(Xz)
        model = KNeighborsRegressor(n_neighbors=min(best_k, len(Xz)), weights="distance").fit(scaler.transform(Xz), yz)
        zone_models[int(z)] = {"model": model, "scaler": scaler}
        print(f"  zone {z} ({['AP1','AP2','AP3'][z]}): {mask.sum()} samples -> trained")

    global_scaler = StandardScaler().fit(X_all)
    global_model = KNeighborsRegressor(n_neighbors=best_k, weights="distance").fit(global_scaler.transform(X_all), y_all)

    bundle = {
        "zone_models": zone_models,
        "global": {"model": global_model, "scaler": global_scaler},
        "ap_names": ["AP1", "AP2", "AP3"],
    }
    joblib.dump(bundle, "hybrid_model.joblib")

    report = {
        "n_samples": int(len(df)),
        "hybrid_best_k": best_k,
        "hybrid_cv_mean_error_m": hybrid_mean,
        "zone_sample_counts": {["AP1", "AP2", "AP3"][int(z)]: int((zones_all == z).sum()) for z in np.unique(zones_all)},
        "note": (
            "'zone' = the AP with the strongest RSSI in a reading, simulating which AP the "
            "phone would actually roam/associate to. This is used as a coarse, robust first "
            "signal; the KNN fine-position step is restricted to training samples from the "
            "same zone when enough data exists, otherwise falls back to the global model."
        ),
    }
    with open("hybrid_training_report.json", "w") as f:
        json.dump(report, f, indent=2)
    print("\nSaved hybrid_model.joblib, hybrid_training_report.json")


if __name__ == "__main__":
    main()
