from sqlalchemy import Column, Integer, String, Boolean, DateTime, ForeignKey, Text, Enum as SQLEnum
from sqlalchemy.orm import relationship
from datetime import datetime
from app.database import Base
import enum

class WishStatus(str, enum.Enum):
    CURRENT = "current"
    COMPLETED = "completed"
    FAILED = "failed"
    ARCHIVED = "archived"
    MISSED = "missed"

class WishVisibility(str, enum.Enum):
    PUBLIC = "public"  # Anyone can see
    FOLLOWERS = "followers"  # Only followers can see
    FRIENDS = "friends"  # Only mutual followers can see
    PRIVATE = "private"  # Only owner can see

class Wish(Base):
    __tablename__ = "wishes"

    id = Column(Integer, primary_key=True, index=True)
    title = Column(String, nullable=False)
    description = Column(Text)
    progress = Column(Integer, default=0)
    is_completed = Column(Boolean, default=False)
    status = Column(SQLEnum(WishStatus), default=WishStatus.CURRENT, nullable=False)
    visibility = Column(SQLEnum(WishVisibility), default=WishVisibility.PUBLIC, nullable=False)
    created_at = Column(DateTime, default=datetime.utcnow)
    target_date = Column(DateTime, nullable=True)
    consequence = Column(Text, nullable=True)  # What happens if goal is not completed
    cover_image = Column(String, nullable=True)  # Cover/main image for the goal
    user_id = Column(Integer, ForeignKey("users.id"))

    owner = relationship("User", back_populates="wishes")
    progress_updates = relationship("ProgressUpdate", back_populates="wish", cascade="all, delete-orphan")
    attachments = relationship("Attachment", back_populates="wish", cascade="all, delete-orphan")
    tags = relationship("Tag", secondary="wish_tags", back_populates="wishes")

