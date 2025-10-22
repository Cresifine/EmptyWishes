from sqlalchemy import Column, Integer, ForeignKey, Float
from app.database import Base

class UserStatistics(Base):
    __tablename__ = "user_statistics"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), unique=True, nullable=False)
    total_wishes = Column(Integer, default=0)
    completed_wishes = Column(Integer, default=0)
    average_progress = Column(Float, default=0.0)
    current_streak = Column(Integer, default=0)
    longest_streak = Column(Integer, default=0)
    total_likes_received = Column(Integer, default=0)
    total_comments_received = Column(Integer, default=0)

