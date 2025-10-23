from sqlalchemy import Column, Integer, String, DateTime, ForeignKey, Boolean, Text
from sqlalchemy.orm import relationship
from datetime import datetime
from app.database import Base

class Notification(Base):
    __tablename__ = "notifications"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)  # Recipient
    type = Column(String, nullable=False)  # 'like', 'comment', 'like_aggregated', 'comment_aggregated'
    wish_id = Column(Integer, ForeignKey("wishes.id"), nullable=True)
    actor_id = Column(Integer, ForeignKey("users.id"), nullable=True)  # Person who liked/commented
    actor_ids = Column(Text, nullable=True)  # JSON array of user IDs for aggregated notifications
    content = Column(Text, nullable=True)  # For comments, store the comment text
    is_read = Column(Boolean, default=False)
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    # Relationships
    user = relationship("User", foreign_keys=[user_id])
    actor = relationship("User", foreign_keys=[actor_id])

