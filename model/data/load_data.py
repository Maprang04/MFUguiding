"""Shared MongoDB/CSV data loader for Wi-Fi fingerprint training."""

import os
from pathlib import Path

import pandas as pd

try:
    from dotenv import load_dotenv

    load_dotenv(Path(__file__).resolve().parents[1] / ".env")
except ImportError:
    pass


MONGODB_CONFIG = {
    "uri": os.environ.get("MONGODB_URI", "mongodb://localhost:27017"),
    "database": os.environ.get("MONGODB_DATABASE", "indoor_navigation"),
    "wifi_collection": os.environ.get(
        "MONGODB_WIFI_COLLECTION",
        "wifi_fingerprints",
    ),
}

CSV_FALLBACK_PATH = Path(__file__).resolve().with_name("wifi_dataset.csv")


def clean_wifi_dataset(df):
    """Remove invalid RSSI rows and robust per-location outliers.

    Values at or below -95 dBm are treated as missing AP readings. For each
    physical reference point, a row is rejected when any AP differs from that
    point's median by more than three scaled median absolute deviations. The
    source database/CSV is never modified.
    """
    required = ["ap1", "ap2", "ap3", "x", "y"]
    missing = [column for column in required if column not in df.columns]
    if missing:
        raise ValueError(
            "Wi-Fi dataset is missing required fields: " + ", ".join(missing)
        )

    cleaned = df.copy()
    cleaned[required] = cleaned[required].apply(pd.to_numeric, errors="coerce")
    cleaned = cleaned.dropna(subset=required)

    ap_cols = ["ap1", "ap2", "ap3"]
    cleaned = cleaned[(cleaned[ap_cols] > -95).all(axis=1)]

    grouped = cleaned.groupby(["x", "y"])[ap_cols]
    medians = grouped.transform("median")
    deviations = (cleaned[ap_cols] - medians).abs()
    mads = deviations.groupby(
        [cleaned["x"], cleaned["y"]]
    ).transform("median")
    mads = mads.replace(0, 1.0)
    within_limit = deviations <= (3.0 * 1.4826 * mads)
    return cleaned[within_limit.all(axis=1)].reset_index(drop=True)


def _load_from_mongodb():
    from pymongo import MongoClient

    with MongoClient(
        MONGODB_CONFIG["uri"],
        serverSelectionTimeoutMS=3000,
    ) as client:
        client.admin.command("ping")
        collection = client[MONGODB_CONFIG["database"]][
            MONGODB_CONFIG["wifi_collection"]
        ]
        documents = list(
            collection.find(
                {},
                {
                    "_id": 0,
                    "id": 1,
                    "ap1": 1,
                    "ap2": 1,
                    "ap3": 1,
                    "x": 1,
                    "y": 1,
                    "created_at": 1,
                },
            )
        )

    if not documents:
        raise ValueError("MongoDB fingerprint collection is empty")
    return pd.DataFrame(documents)


def load_wifi_dataset(prefer_db=True, clean=True):
    """Load fingerprints from MongoDB, falling back to the CSV snapshot."""
    if prefer_db:
        try:
            df = _load_from_mongodb()
            source = (
                f"MongoDB ({MONGODB_CONFIG['database']}/"
                f"{MONGODB_CONFIG['wifi_collection']})"
            )
        except Exception as error:
            print(
                f"[load_data] Could not read from MongoDB ({error!r}); "
                "falling back to CSV snapshot."
            )
            df = pd.read_csv(CSV_FALLBACK_PATH)
            source = f"CSV snapshot ({CSV_FALLBACK_PATH})"
    else:
        df = pd.read_csv(CSV_FALLBACK_PATH)
        source = f"CSV snapshot ({CSV_FALLBACK_PATH})"

    raw_count = len(df)
    if clean:
        df = clean_wifi_dataset(df)
        print(
            f"[load_data] Loaded {raw_count} rows from {source}; "
            f"kept {len(df)} after noise filtering"
        )
    else:
        print(
            f"[load_data] Loaded {raw_count} rows from {source} "
            "(noise filtering disabled)"
        )
    return df


if __name__ == "__main__":
    dataset = load_wifi_dataset()
    print(dataset.head())
    print(
        f"\n{len(dataset)} rows, "
        f"{len(dataset[['x', 'y']].drop_duplicates())} unique reference points"
    )
