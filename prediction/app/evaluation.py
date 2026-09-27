from math import log


def evaluate(probabilities: list[list[float]], outcomes: list[int]) -> dict:
    if not probabilities or len(probabilities) != len(outcomes):
        raise ValueError('Aligned nonempty probabilities and outcomes required')
    brier, loss, correct = 0.0, 0.0, 0
    bins = [{'count': 0, 'sum_probability': 0.0, 'sum_outcomes': 0} for _ in range(10)]
    for ps, outcome in zip(probabilities, outcomes):
        if len(ps) < 2 or not 0 <= outcome < len(ps) or any(not 0 <= p <= 1 for p in ps) or abs(sum(ps) - 1) > 1e-6:
            raise ValueError('Invalid categorical probability vector')
        brier += sum((p - int(i == outcome)) ** 2 for i, p in enumerate(ps))
        loss -= log(max(ps[outcome], 1e-15))
        selected = max(range(len(ps)), key=ps.__getitem__)
        correct += int(selected == outcome)
        bucket = bins[min(9, int(ps[selected] * 10))]
        bucket['count'] += 1
        bucket['sum_probability'] += ps[selected]
        bucket['sum_outcomes'] += int(selected == outcome)
    n = len(outcomes)
    return {'total': n, 'correct': correct, 'incorrect': n - correct, 'accuracy': correct / n,
            'brier_score': brier / n, 'log_loss': loss / n,
            'calibration': [{'lower': i / 10, 'upper': (i + 1) / 10, 'count': b['count'],
                             'mean_probability': b['sum_probability'] / b['count'] if b['count'] else None,
                             'observed_frequency': b['sum_outcomes'] / b['count'] if b['count'] else None}
                            for i, b in enumerate(bins)]}
