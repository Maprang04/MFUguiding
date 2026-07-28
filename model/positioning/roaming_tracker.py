"""Per-client roaming state with confirmation to prevent AP ping-pong."""

from dataclasses import dataclass


@dataclass(frozen=True)
class RoamingUpdate:
    current_ap: str
    previous_ap: str | None = None
    roaming_confirmed: bool = False
    candidate_ap: str | None = None
    candidate_count: int = 0


class RoamingTracker:
    def __init__(self, required_confirmations=3):
        if required_confirmations < 1:
            raise ValueError("required_confirmations must be at least 1")
        self.required_confirmations = int(required_confirmations)
        self._states = {}

    def update(self, client_id, detected_ap):
        if not client_id or not detected_ap:
            raise ValueError("client_id and detected_ap are required")
        state = self._states.get(client_id)
        if state is None:
            self._states[client_id] = {
                "current_ap": detected_ap,
                "candidate_ap": None,
                "candidate_count": 0,
            }
            return RoamingUpdate(current_ap=detected_ap)

        if detected_ap == state["current_ap"]:
            state["candidate_ap"] = None
            state["candidate_count"] = 0
            return RoamingUpdate(current_ap=state["current_ap"])

        if detected_ap == state["candidate_ap"]:
            state["candidate_count"] += 1
        else:
            state["candidate_ap"] = detected_ap
            state["candidate_count"] = 1

        if state["candidate_count"] >= self.required_confirmations:
            previous_ap = state["current_ap"]
            state["current_ap"] = detected_ap
            state["candidate_ap"] = None
            state["candidate_count"] = 0
            return RoamingUpdate(
                current_ap=detected_ap,
                previous_ap=previous_ap,
                roaming_confirmed=True,
            )

        return RoamingUpdate(
            current_ap=state["current_ap"],
            candidate_ap=state["candidate_ap"],
            candidate_count=state["candidate_count"],
        )

