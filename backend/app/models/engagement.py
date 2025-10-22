from sqlalchemy import Column, Integer, ForeignKey, DateTime, String
from datetime import datetime
from app.database import Base

class Engagement(Base):
    __tablename__ = "engagements"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    wish_id = Column(Integer, ForeignKey("wishes.id"), nullable=False)
    action_type = Column(String, nullable=False)  # 'like', 'comment', 'view', 'share'
    created_at = Column(DateTime, default=datetime.utcnow)

