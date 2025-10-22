from pydantic import BaseModel
from datetime import datetime
from typing import Optional

class LikeCreate(BaseModel):
    wish_id: int

class LikeResponse(BaseModel):
    id: int
    user_id: int
    wish_id: int
    created_at: datetime

    class Config:
        from_attributes = True

class CommentCreate(BaseModel):
    wish_id: int
    content: str

class CommentUpdate(BaseModel):
    content: str

class CommentResponse(BaseModel):
    id: int
    user_id: int
    wish_id: int
    content: str
    created_at: datetime
    updated_at: datetime

    class Config:
        from_attributes = True

class ViewCreate(BaseModel):
    wish_id: int

class EngagementStats(BaseModel):
    wish_id: int
    likes_count: int
    comments_count: int
    views_count: int
    is_liked: bool = False

