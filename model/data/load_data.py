"""
load_data.py
--------------
Shared data-loading helper for the training scripts. Reads the WiFi
fingerprint dataset straight from MySQL (same DB the Node.js backend
connects to), and falls back to the CSV snapshot in data/wifi_dataset.csv
if the database isn't reachable (e.g. running this on a machine that
doesn't have the DB, or before the DB is set up).

Configure the connection via environment variables (put these in a
`.env` file at the project root, or export them in your shell) — this
mirrors the same connection details used by backend-node's mysql pool:

    DB_HOST=localhost
    DB_USER=root
    DB_PASSWORD=
    DB_NAME=indoor_navigation
    DB_PORT=3306

If you don't set any of these, the defaults below match the pool config
you're already using in Node.js:

    host: "localhost", user: "root", password: "", database: "indoor_navigation"
"""
import os
import pandas as pd

try:
    from dotenv import load_dotenv
    load_dotenv()
except ImportError:
    pass  # python-dotenv not installed -> just rely on already-exported env vars

DB_CONFIG = {
    "host": os.environ.get("DB_HOST", "localhost"),
    "user": os.environ.get("DB_USER", "root"),
    "password": os.environ.get("DB_PASSWORD", ""),
    "database": os.environ.get("DB_NAME", "indoor_navigation"),
    "port": int(os.environ.get("DB_PORT", "3306")),
}

CSV_FALLBACK_PATH = os.path.join(os.path.dirname(__file__), "wifi_dataset.csv")


def clean_wifi_dataset(df):
    """Remove invalid/missing RSSI rows and robust per-location outliers.

    Values at or below -95 dBm are treated as missing AP readings. For each
    physical reference point, a row is also rejected when any AP differs from
    that point's median by more than three scaled median absolute deviations.
    The source database/CSV is never modified.
    """
    required = ["ap1", "ap2", "ap3", "x", "y"]
    cleaned = df.copy()
    cleaned[required] = cleaned[required].apply(pd.to_numeric, errors="coerce")
    cleaned = cleaned.dropna(subset=required)

    ap_cols = ["ap1", "ap2", "ap3"]
    cleaned = cleaned[(cleaned[ap_cols] > -95).all(axis=1)]

    grouped = cleaned.groupby(["x", "y"])[ap_cols]
    medians = grouped.transform("median")
    deviations = (cleaned[ap_cols] - medians).abs()
    mads = deviations.groupby([cleaned["x"], cleaned["y"]]).transform("median")
    # A zero MAD is common in a small fingerprint set; use 1 dBm so that
    # identical readings remain valid while obvious deviations are rejected.
    mads = mads.replace(0, 1.0)
    within_limit = deviations <= (3.0 * 1.4826 * mads)
    return cleaned[within_limit.all(axis=1)].reset_index(drop=True)


def load_wifi_dataset(prefer_db=True, clean=True):
    """Returns a DataFrame with columns: ap1, ap2, ap3, x, y (+ id/created_at if from DB/CSV).
    Tries MySQL first (if prefer_db=True), falls back to the CSV snapshot."""
    if prefer_db:
        try:
            from sqlalchemy import create_engine
            url = (
                f"mysql+pymysql://{DB_CONFIG['user']}:{DB_CONFIG['password']}"
                f"@{DB_CONFIG['host']}:{DB_CONFIG['port']}/{DB_CONFIG['database']}"
            )
            engine = create_engine(url, connect_args={"connect_timeout": 3})
            df = pd.read_sql("SELECT id, ap1, ap2, ap3, x, y, created_at FROM wifi_dataset", engine)
            source = f"MySQL ({DB_CONFIG['host']}/{DB_CONFIG['database']})"
        except Exception as e:
            print(f"[load_data] Could not read from MySQL ({e!r}); falling back to CSV snapshot.")
            df = pd.read_csv(CSV_FALLBACK_PATH)
            source = f"CSV snapshot ({CSV_FALLBACK_PATH})"
    else:
        df = pd.read_csv(CSV_FALLBACK_PATH)
        source = f"CSV snapshot ({CSV_FALLBACK_PATH})"

    raw_count = len(df)
    if clean:
        df = clean_wifi_dataset(df)
        print(f"[load_data] Loaded {raw_count} rows from {source}; kept {len(df)} after noise filtering")
    else:
        print(f"[load_data] Loaded {raw_count} rows from {source} (noise filtering disabled)")
    return df


if __name__ == "__main__":
    df = load_wifi_dataset()
    print(df.head())
    print(f"\n{len(df)} rows, {len(df[['x','y']].drop_duplicates())} unique reference points")
