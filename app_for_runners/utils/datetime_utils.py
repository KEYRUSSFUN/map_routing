from datetime import datetime, timezone


def utc_isoformat(value):
    """Serialize DB datetime as explicit UTC ISO-8601 for clients."""
    if value is None:
        return None
    if value.tzinfo is None:
        value = value.replace(tzinfo=timezone.utc)
    else:
        value = value.astimezone(timezone.utc)
    return value.isoformat()
