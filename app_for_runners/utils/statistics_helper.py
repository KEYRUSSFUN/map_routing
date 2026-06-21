from datetime import date, datetime, timezone

from extensions import db
from models import UserInfo, UserStatistic
from utils.user_info_helper import ensure_user_info_exists


def route_activity_date(route):
    if route.started_at:
        dt = route.started_at
        if dt.tzinfo is not None:
            return dt.astimezone(timezone.utc).date()
        return dt.date()
    if route.creation_date:
        dt = route.creation_date
        if dt.tzinfo is not None:
            return dt.astimezone(timezone.utc).date()
        return dt.date()
    return None


def estimate_steps(distance_m, user_id):
    distance = float(distance_m or 0)
    if distance <= 0:
        return 0

    info = UserInfo.query.filter_by(id_User=user_id).first()
    height = float(info.height) if info and info.height else 170.0
    step_length = (height * 0.415) / 100.0
    if step_length <= 0:
        step_length = 0.75
    return int(round(distance / step_length))


def apply_stat_delta(
    user_id,
    *,
    distance=0.0,
    steps=0,
    calories=0.0,
    activity_date=None,
    multiplier=1,
):
    ensure_user_info_exists(user_id)

    if activity_date is None:
        stat_date = datetime.now(timezone.utc).date()
    elif isinstance(activity_date, datetime):
        stat_date = (
            activity_date.astimezone(timezone.utc).date()
            if activity_date.tzinfo is not None
            else activity_date.date()
        )
    elif isinstance(activity_date, date):
        stat_date = activity_date
    else:
        stat_date = datetime.now(timezone.utc).date()

    delta_distance = float(distance or 0) * multiplier
    delta_steps = int(steps or 0) * multiplier
    delta_calories = float(calories or 0) * multiplier

    if delta_distance == 0 and delta_steps == 0 and delta_calories == 0:
        return

    existing = UserStatistic.query.filter_by(
        id_User=user_id,
        date=stat_date,
    ).first()

    if existing:
        existing.distance = max(0.0, float(existing.distance or 0) + delta_distance)
        existing.steps = max(0, int(existing.steps or 0) + delta_steps)
        existing.calories = max(0.0, float(existing.calories or 0) + delta_calories)
        return

    if multiplier < 0:
        return

    db.session.add(
        UserStatistic(
            id_User=user_id,
            distance=max(0.0, delta_distance),
            steps=max(0, delta_steps),
            calories=max(0.0, delta_calories),
            date=stat_date,
        )
    )


def apply_route_to_statistics(route, *, multiplier=1):
    if route is None:
        return

    distance = float(route.distance or 0)
    calories = float(route.calories or 0)
    steps = estimate_steps(distance, route.id_User)
    activity_date = route_activity_date(route)

    apply_stat_delta(
        route.id_User,
        distance=distance,
        steps=steps,
        calories=calories,
        activity_date=activity_date,
        multiplier=multiplier,
    )
