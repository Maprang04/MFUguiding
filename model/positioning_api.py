"""HTTP API used by the Node.js navigation backend."""

from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parent
sys.path.insert(0, str(ROOT))

from fastapi import FastAPI, Request  # noqa: E402
from fastapi.responses import JSONResponse  # noqa: E402
from pydantic import BaseModel  # noqa: E402

from positioning.rssi_filter import InvalidRssiError  # noqa: E402
from positioning.service import PositioningError, PositioningService  # noqa: E402


app = FastAPI(title="MFU Indoor Positioning API", version="1.0.0")
service = PositioningService()


class CreateSessionRequest(BaseModel):
    session_id: str
    client_id: str
    destination_id: str


class ObservationRequest(BaseModel):
    associated_ap: str
    rssi: float
    timestamp: str | None = None


class DestinationRequest(BaseModel):
    destination_id: str


@app.exception_handler(PositioningError)
async def positioning_error_handler(_request: Request, error: PositioningError):
    return JSONResponse(
        status_code=error.status_code,
        content={"error": {"code": error.code, "message": str(error)}},
    )


@app.exception_handler(InvalidRssiError)
async def invalid_rssi_handler(_request: Request, error: InvalidRssiError):
    return JSONResponse(
        status_code=400,
        content={"error": {"code": "INVALID_RSSI", "message": str(error)}},
    )


@app.get("/health")
def health():
    return service.health()


@app.post("/sessions", status_code=201)
def create_session(body: CreateSessionRequest):
    return service.create_session(body.session_id, body.client_id, body.destination_id)


@app.get("/sessions/{session_id}")
def get_session(session_id: str):
    return service.get_session(session_id)


@app.post("/sessions/{session_id}/observations")
def submit_observation(session_id: str, body: ObservationRequest):
    return service.submit_observation(session_id, body.associated_ap, body.rssi)


@app.patch("/sessions/{session_id}/destination")
def change_destination(session_id: str, body: DestinationRequest):
    return service.change_destination(session_id, body.destination_id)


@app.delete("/sessions/{session_id}")
def delete_session(session_id: str):
    return service.delete_session(session_id)

