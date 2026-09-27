from datetime import datetime
from pydantic import BaseModel, Field, AwareDatetime, model_validator


class Observation(BaseModel):
    fixture_id: int = Field(gt=0)
    played_at: AwareDatetime
    goals_for: int = Field(ge=0, le=30)
    goals_against: int = Field(ge=0, le=30)
    home: bool


class PredictionRequest(BaseModel):
    fixture_id: int = Field(gt=0)
    kickoff: AwareDatetime
    snapshot_at: AwareDatetime
    home_history: list[Observation] = Field(min_length=5, max_length=30)
    away_history: list[Observation] = Field(min_length=5, max_length=30)
    lineups_available: bool = False
    injuries_available: bool = False

    @model_validator(mode='after')
    def no_leakage(self):
        if self.snapshot_at >= self.kickoff:
            raise ValueError('Snapshot must precede kickoff')
        for history in (self.home_history, self.away_history):
            ids = [row.fixture_id for row in history]
            if len(set(ids)) != len(ids):
                raise ValueError('Duplicate historical fixture')
            if self.fixture_id in ids:
                raise ValueError('Target fixture cannot be part of training data')
            if any(row.played_at >= self.snapshot_at for row in history):
                raise ValueError('Historical matches must precede the snapshot')
        return self
