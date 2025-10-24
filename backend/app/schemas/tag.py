from pydantic import BaseModel
from datetime import datetime
from typing import Optional

class TagBase(BaseModel):
    name: str

class TagCreate(TagBase):
    pass

class TagResponse(TagBase):
    id: int
    usage_count: int
    created_at: datetime

    class Config:
        from_attributes = True

class PopularTagResponse(BaseModel):
    id: int
    name: str
    usage_count: int

    class Config:
        from_attributes = True

