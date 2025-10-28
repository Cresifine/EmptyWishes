from sqlalchemy import Column, Integer, String, DateTime, ForeignKey, Text
from sqlalchemy.orm import relationship
from datetime import datetime, timezone
from app.database import Base

class ProgressUpdate(Base):
    __tablename__ = "progress_updates"

    id = Column(Integer, primary_key=True, index=True)
    wish_id = Column(Integer, ForeignKey("wishes.id"), nullable=False)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    content = Column(Text, nullable=False)  # Update text/comment
    image_url = Column(String, nullable=True)  # Optional photo with the update
    progress_value = Column(Integer, nullable=True)  # Optional progress snapshot at this update
    created_at = Column(DateTime, default=lambda: datetime.now(timezone.utc))

    wish = relationship("Wish", back_populates="progress_updates")
    user = relationship("User")
    attachments = relationship("Attachment", back_populates="progress_update", cascade="all, delete-orphan")

