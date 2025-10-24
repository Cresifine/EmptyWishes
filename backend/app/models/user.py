from sqlalchemy import Column, Integer, String, Boolean, DateTime
from sqlalchemy.orm import relationship
from datetime import datetime
from app.database import Base

class User(Base):
    __tablename__ = "users"

    id = Column(Integer, primary_key=True, index=True)
    email = Column(String, unique=True, index=True, nullable=False)
    username = Column(String, unique=True, index=True, nullable=False)
    hashed_password = Column(String, nullable=False)
    is_active = Column(Boolean, default=True)
    created_at = Column(DateTime, default=datetime.utcnow)
    
    # Social media links
    instagram = Column(String, nullable=True)
    twitter = Column(String, nullable=True)
    linkedin = Column(String, nullable=True)
    github = Column(String, nullable=True)

    wishes = relationship("Wish", back_populates="owner")
    following = relationship("Follow", foreign_keys="[Follow.follower_id]", back_populates="follower")
    followers = relationship("Follow", foreign_keys="[Follow.following_id]", back_populates="following")

