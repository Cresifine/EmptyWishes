from pydantic import BaseModel
from datetime import datetime
from typing import Optional

class ProgressUpdateCreate(BaseModel):
    content: str
    image_url: Optional[str] = None
    progress_value: Optional[int] = None

class ProgressUpdateResponse(BaseModel):
    id: int
    wish_id: int
    user_id: int
    content: str
    image_url: Optional[str]
    progress_value: Optional[int]
    created_at: datetime

    class Config:
        from_attributes = True

