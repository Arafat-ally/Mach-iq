import os
import secrets
from datetime import datetime, timezone
from fastapi import FastAPI, Header, HTTPException, Depends
from .schemas import PredictionRequest
from .model import predict, VERSION

app = FastAPI(title='MatchIQ Prediction', docs_url=None, redoc_url=None)


def authenticate(x_service_key: str = Header(default='')):
    expected = os.environ.get('PREDICTION_SERVICE_KEY', '')
    if not expected or not secrets.compare_digest(x_service_key, expected):
        raise HTTPException(401, 'Unauthorized')


@app.get('/health')
def health():
    return {'status': 'ok' if os.environ.get('PREDICTION_SERVICE_KEY') else 'not_configured'}


@app.get('/version', dependencies=[Depends(authenticate)])
def version():
    return {'model_version': VERSION, 'calibrated': False}


@app.post('/predict', dependencies=[Depends(authenticate)])
def infer(request: PredictionRequest):
    now = datetime.now(timezone.utc)
    if request.kickoff <= now or request.snapshot_at > now:
        raise HTTPException(422, 'Prediction requires a past snapshot and future kickoff')
    try:
        return predict(request)
    except ValueError as error:
        raise HTTPException(422, str(error)) from error
