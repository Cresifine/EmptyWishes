from pydantic import BaseModel
from datetime import datetime
from typing import Optional


class MilestoneBase(BaseModel):
    title: str
    description: Optional[str] = None
    order_index: int = 0
    points: int = 1
    target_date: Optional[datetime] = None


class MilestoneCreate(MilestoneBase):
    wish_id: int


class MilestoneUpdate(BaseModel):
    title: Optional[str] = None
    description: Optional[str] = None
    order_index: Optional[int] = None
    points: Optional[int] = None
    target_date: Optional[datetime] = None
    is_completed: Optional[bool] = None


class Milestone(MilestoneBase):
    id: int
    wish_id: int
    is_completed: bool
    completed_at: Optional[datetime] = None
    created_at: datetime
    updated_at: datetime

    class Config:
        from_attributes = True


