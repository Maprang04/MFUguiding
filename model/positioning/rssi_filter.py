"""Validation and median filtering for controller RSSI observations."""

from collections import defaultdict, deque
from statistics import median


class InvalidRssiError(ValueError):
    """Raised when a controller observation does not contain usable RSSI."""


class RssiMedianFilter:
    """Keep independent rolling RSSI windows for each client/AP pair."""

    def __init__(self, window_size=5, valid_min_exclusive=-95, valid_max_exclusive=-20):
        if window_size < 1:
            raise ValueError("window_size must be at least 1")
        self.window_size = int(window_size)
        self.valid_min = float(valid_min_exclusive)
        self.valid_max = float(valid_max_exclusive)
        self._windows = defaultdict(lambda: deque(maxlen=self.window_size))

    def update(self, client_id, ap_name, rssi):
        if not client_id or not ap_name:
            raise ValueError("client_id and ap_name are required")
        try:
            value = float(rssi)
        except (TypeError, ValueError) as exc:
            raise InvalidRssiError(f"RSSI is not numeric: {rssi!r}") from exc
        if not self.valid_min < value < self.valid_max:
            raise InvalidRssiError(
                f"RSSI {value:g} is outside ({self.valid_min:g}, {self.valid_max:g}) dBm"
            )
        window = self._windows[(str(client_id), str(ap_name))]
        window.append(value)
        return float(median(window))

    def samples(self, client_id, ap_name):
        return tuple(self._windows.get((str(client_id), str(ap_name)), ()))

    def median(self, client_id, ap_name):
        values = self.samples(client_id, ap_name)
        if not values:
            return None
        return float(median(values))
