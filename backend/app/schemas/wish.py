from pydantic import BaseModel
from datetime import datetime
from typing import Optional
from enum import Enum

class WishStatus(str, Enum):
    CURRENT = "current"
    COMPLETED = "completed"
    ARCHIVED = "archived"
    MISSED = "missed"

class WishVisibility(str, Enum):
    PUBLIC = "public"
    FOLLOWERS = "followers"
    FRIENDS = "friends"
    PRIVATE = "private"

class WishCreate(BaseModel):
    title: str
    description: Optional[str] = None
    target_date: Optional[datetime] = None
    consequence: Optional[str] = None
    cover_image: Optional[str] = None
    visibility: Optional[WishVisibility] = WishVisibility.PUBLIC

class WishUpdate(BaseModel):
    title: Optional[str] = None
    description: Optional[str] = None
    progress: Optional[int] = None
    is_completed: Optional[bool] = None
    status: Optional[WishStatus] = None
    visibility: Optional[WishVisibility] = None
    consequence: Optional[str] = None
    cover_image: Optional[str] = None

class WishResponse(BaseModel):
    id: int
    title: str
    description: Optional[str]
    progress: int
    is_completed: bool
    status: str
    created_at: datetime
    target_date: Optional[datetime]
    consequence: Optional[str]
    cover_image: Optional[str]
    user_id: int

    class Config:
        from_attributes = True

