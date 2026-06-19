from datetime import datetime, timedelta, timezone

from models import Route, UserStatistic

ALLOWED_ACHIEVEMENT_IDS = frozenset({
    'firstWorkout',
    'earlyBird',
    'speedDemon',
    'peakForm',
    'streak7',
    'century',
    'marathoner',
    'ninja',
    'explorer',
    'photographer',
    'traveler',
    'worldTraveler',
})


def _active_days_from_stats(stats):
    days = set()
    for row in stats:
        if (row.distance or 0) > 0 and row.date:
            days.add(row.date)
    return days


def _current_streak(active_days):
    if not active_days:
        return 0

    today = datetime.now(timezone.utc).date()
    anchor = max(active_days)
    if anchor < today - timedelta(days=1):
        return 0

    streak = 0
    cursor = anchor
    while cursor in active_days:
        streak += 1
        cursor -= timedelta(days=1)
    return streak


def _route_local_start_hour(route):
    if route.started_at_local_hour is not None:
        return route.started_at_local_hour
    if route.started_at is not None:
        return route.started_at.hour
    return None


def _total_distance_m(stats):
    return sum((row.distance or 0) for row in stats)


def evaluate_achievement_candidates(user_id, *, now=None):
    """Считает достижения только по серверной статистике и своим маршрутам."""
    now = now or datetime.now(timezone.utc)
    stats = UserStatistic.query.filter_by(id_User=user_id).all()
    routes = Route.query.filter_by(id_User=user_id).all()

    total_distance_m = _total_distance_m(stats)
    active_days = _active_days_from_stats(stats)
    streak = _current_streak(active_days)

    high_effort_routes = sum(
        1 for route in routes if (route.effort_level or 0) >= 4
    )

    checks = {
        'firstWorkout': bool(routes) or total_distance_m > 0,
        'earlyBird': any(
            (hour := _route_local_start_hour(route)) is not None and hour < 7
            for route in routes
        ),
        'speedDemon': any(
            (route.distance or 0) >= 3000 and (route.avg_speed_kmh or 0) >= 12
            for route in routes
        ),
        'peakForm': any(
            (route.elevation_gain_m or 0) >= 300 for route in routes
        ),
        'streak7': streak >= 7,
        'century': total_distance_m >= 100_000,
        'marathoner': any((route.distance or 0) >= 42_000 for route in routes),
        'ninja': high_effort_routes >= 5,
        'explorer': len(routes) >= 10,
        'photographer': any(route.photo_filename for route in routes),
        'traveler': total_distance_m >= 500_000,
        'worldTraveler': total_distance_m >= 1_000_000,
    }

    candidates = []
    for achievement_id, unlocked in checks.items():
        if unlocked:
            candidates.append({
                'achievement_id': achievement_id,
                'unlocked_at': now.replace(tzinfo=timezone.utc).isoformat(),
            })

    return candidates
