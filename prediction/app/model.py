from math import exp
from .features import team_rates
from .schemas import PredictionRequest

VERSION = 'matchiq_poisson_v1.0.0'


def poisson(rate: float) -> list[float]:
    values = [exp(-rate)]
    for k in range(1, 61):
        values.append(values[-1] * rate / k)
    return values


def predict(request: PredictionRequest) -> dict:
    h = team_rates(request.home_history, request.snapshot_at, True)
    a = team_rates(request.away_history, request.snapshot_at, False)
    # Arithmetic attack/defence combination, bounded only to keep numerical tails stable.
    home_rate = max(0.05, min(12.0, (h['scored'] + a['conceded']) / 2))
    away_rate = max(0.05, min(12.0, (a['scored'] + h['conceded']) / 2))
    hp, ap = poisson(home_rate), poisson(away_rate)
    grid = [(i, j, ph * pa) for i, ph in enumerate(hp) for j, pa in enumerate(ap)]
    mass = sum(p for _, _, p in grid)
    probability = lambda condition: sum(p for i, j, p in grid if condition(i, j)) / mass
    home = probability(lambda i, j: i > j)
    draw = probability(lambda i, j: i == j)
    away = 1 - home - draw
    yes = probability(lambda i, j: i > 0 and j > 0)
    markets = {'1x2': {'home': home, 'draw': draw, 'away': away},
               'double_chance': {'home_draw': home + draw, 'home_away': home + away,
                                 'draw_away': draw + away},
               'btts': {'yes': yes, 'no': 1 - yes}}
    for line in (0.5, 1.5, 2.5, 3.5):
        over = probability(lambda i, j: i + j > line)
        markets[f'goals_{line}'] = {'over': over, 'under': 1 - over}
    # Model probability is separate from coverage. This baseline never claims HIGH
    # without richer features and a validated calibration dataset.
    quality = 'MEDIUM' if min(h['sample'], a['sample']) >= 10 and min(h['venue_sample'], a['venue_sample']) >= 5 else 'LOW'
    return {
        'fixture_id': request.fixture_id, 'model_version': VERSION,
        'data_snapshot_time': request.snapshot_at.isoformat(),
        'data_quality': quality,
        'expected_goals': {'home': home_rate, 'away': away_rate},
        'markets': {market: {selection: {'probability': p,
                     'fair_odds': round(1 / p, 4) if p > 1e-9 else None}
                     for selection, p in values.items()} for market, values in markets.items()},
        'factors': [
            {'team': 'home', 'scored_in': h['scored_in'], 'sample_size': h['sample']},
            {'team': 'away', 'conceded_in': a['conceded_in'], 'sample_size': a['sample']},
        ],
        'limitations': ['Independent Poisson baseline; not yet empirically calibrated.',
                       'Injury, lineup, opponent-strength and xG effects are not modeled.',
                       'Predictions are statistical estimates and do not guarantee outcomes.'],
    }
