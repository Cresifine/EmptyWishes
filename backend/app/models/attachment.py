from sqlalchemy import Column, Integer, String, DateTime, ForeignKey, Text
from sqlalchemy.orm import relationship
from datetime import datetime
from app.database import Base

class Attachment(Base):
    __tablename__ = "attachments"

    id = Column(Integer, primary_key=True, index=True)
    file_name = Column(String, nullable=False)
    file_path = Column(String, nullable=False)  # Path in uploads directory
    file_type = Column(String, nullable=False)  # MIME type
    file_size = Column(Integer, nullable=False)  # Size in bytes
    created_at = Column(DateTime, default=datetime.utcnow)
    
    # Polymorphic association - can belong to either Wish or ProgressUpdate
    wish_id = Column(Integer, ForeignKey("wishes.id"), nullable=True)
    progress_update_id = Column(Integer, ForeignKey("progress_updates.id"), nullable=True)
    
    wish = relationship("Wish", back_populates="attachments")
    progress_update = relationship("ProgressUpdate", back_populates="attachments")

