from sqlalchemy import Column, Integer, ForeignKey, DateTime, UniqueConstraint
from sqlalchemy.orm import relationship
from datetime import datetime
from app.database import Base

class Follow(Base):
    __tablename__ = "follows"
    __table_args__ = (
        UniqueConstraint('follower_id', 'following_id', name='unique_follow'),
    )

    id = Column(Integer, primary_key=True, index=True)
    follower_id = Column(Integer, ForeignKey("users.id"), nullable=False)  # User who follows
    following_id = Column(Integer, ForeignKey("users.id"), nullable=False)  # User being followed
    created_at = Column(DateTime, default=datetime.utcnow)

    follower = relationship("User", foreign_keys=[follower_id], back_populates="following")
    following = relationship("User", foreign_keys=[following_id], back_populates="followers")

