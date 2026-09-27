from datetime import datetime, timedelta, timezone
import pytest
from app.schemas import PredictionRequest
from app.model import predict
from app.evaluation import evaluate
from app.main import app
from fastapi.testclient import TestClient


def sample():
    now = datetime.now(timezone.utc)
    history = [{'fixture_id': i + 1, 'played_at': now - timedelta(days=i + 1),
                'goals_for': i % 4, 'goals_against': i % 3, 'home': i % 2 == 0} for i in range(10)]
    return dict(fixture_id=99, kickoff=now + timedelta(days=1), snapshot_at=now,
                home_history=history, away_history=history)


def test_probability_complements_and_fair_odds():
    result = predict(PredictionRequest(**sample()))
    for name, selections in result['markets'].items():
        if name != 'double_chance':
            assert sum(v['probability'] for v in selections.values()) == pytest.approx(1)
        for v in selections.values():
            assert 0 <= v['probability'] <= 1
            assert v['fair_odds'] == pytest.approx(1 / v['probability'], abs=0.0001)
    assert result['markets']['1x2']['home']['probability'] == pytest.approx(result['markets']['1x2']['away']['probability'], abs=0.1)


def test_leakage_and_duplicate_rejected():
    data = sample()
    data['home_history'][0]['fixture_id'] = 99
    with pytest.raises(ValueError):
        PredictionRequest(**data)
    data = sample()
    data['home_history'][0]['played_at'] = data['kickoff']
    with pytest.raises(ValueError):
        PredictionRequest(**data)


def test_insufficient_sample():
    data = sample()
    data['home_history'] = data['home_history'][:4]
    with pytest.raises(ValueError):
        PredictionRequest(**data)


def test_monotonic_goal_lines():
    result = predict(PredictionRequest(**sample()))['markets']
    assert result['goals_0.5']['over']['probability'] >= result['goals_1.5']['over']['probability'] >= result['goals_2.5']['over']['probability'] >= result['goals_3.5']['over']['probability']


def test_evaluation_retains_losses():
    result = evaluate([[0.8, 0.2], [0.9, 0.1]], [0, 1])
    assert result['correct'] == result['incorrect'] == 1
    assert result['brier_score'] == pytest.approx(0.85)
    assert result['log_loss'] > 1


def test_api_auth_and_kickoff(monkeypatch):
    monkeypatch.setenv('PREDICTION_SERVICE_KEY', 'test-key')
    client = TestClient(app)
    assert client.get('/health').json()['status'] == 'ok'
    assert client.get('/version').status_code == 401
    headers = {'x-service-key': 'test-key'}
    payload = PredictionRequest(**sample()).model_dump(mode='json')
    assert client.post('/predict', json=payload, headers=headers).status_code == 200
    payload['kickoff'] = (datetime.now(timezone.utc) - timedelta(seconds=1)).isoformat()
    assert client.post('/predict', json=payload, headers=headers).status_code == 422
