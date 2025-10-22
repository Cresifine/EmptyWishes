from sqlalchemy import Column, Integer, ForeignKey, DateTime
from datetime import datetime
from app.database import Base

class View(Base):
    __tablename__ = "views"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=True)  # Nullable for anonymous views
    wish_id = Column(Integer, ForeignKey("wishes.id"), nullable=False)
    created_at = Column(DateTime, default=datetime.utcnow)

