from sqlalchemy import Column, Integer, String, DateTime, ForeignKey, Table
from sqlalchemy.orm import relationship
from datetime import datetime
from app.database import Base

# Association table for many-to-many relationship between wishes and tags
wish_tags = Table(
    'wish_tags',
    Base.metadata,
    Column('wish_id', Integer, ForeignKey('wishes.id'), primary_key=True),
    Column('tag_id', Integer, ForeignKey('tags.id'), primary_key=True),
    Column('created_at', DateTime, default=datetime.utcnow)
)

class Tag(Base):
    __tablename__ = "tags"

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String, unique=True, index=True, nullable=False)
    created_at = Column(DateTime, default=datetime.utcnow)
    usage_count = Column(Integer, default=0)  # Track how many times this tag is used

    # Relationship to wishes
    wishes = relationship("Wish", secondary=wish_tags, back_populates="tags")

