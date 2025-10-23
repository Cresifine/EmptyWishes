from pydantic import BaseModel
from datetime import datetime
from typing import Optional, List

class NotificationBase(BaseModel):
    type: str
    wish_id: Optional[int] = None
    content: Optional[str] = None

class NotificationCreate(NotificationBase):
    user_id: int
    actor_id: Optional[int] = None

class NotificationResponse(NotificationBase):
    id: int
    user_id: int
    actor_id: Optional[int] = None
    actor_ids: Optional[str] = None
    is_read: bool
    created_at: datetime
    updated_at: datetime
    
    # Additional fields for frontend
    actor_username: Optional[str] = None
    actor_usernames: Optional[List[str]] = None
    wish_title: Optional[str] = None
    count: Optional[int] = None

    class Config:
        from_attributes = True

