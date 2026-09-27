from math import exp
from .schemas import Observation


def team_rates(history: list[Observation], at, home: bool) -> dict:
    # Time decay with a 90-day scale and venue weighting; no fabricated league prior.
    weights = [exp(-max(0, (at - row.played_at).days) / 90) *
               (1.0 if row.home == home else 0.5) for row in history]
    total = sum(weights)
    if total < 0.01:
        raise ValueError('Historical data is too old')
    return {
        'scored': sum(row.goals_for * w for row, w in zip(history, weights)) / total,
        'conceded': sum(row.goals_against * w for row, w in zip(history, weights)) / total,
        'sample': len(history),
        'scored_in': sum(row.goals_for > 0 for row in history),
        'conceded_in': sum(row.goals_against > 0 for row in history),
        'venue_sample': sum(row.home == home for row in history),
    }
