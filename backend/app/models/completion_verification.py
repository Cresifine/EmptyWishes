from sqlalchemy import Column, Integer, String, Boolean, DateTime, ForeignKey, Text, Enum as SQLEnum
from sqlalchemy.orm import relationship
from datetime import datetime, timezone
from app.database import Base
import enum


class VerificationStatus(str, enum.Enum):
    PENDING = "pending"
    APPROVED = "approved"
    DISPUTED = "disputed"


class CompletionVerification(Base):
    __tablename__ = "completion_verifications"

    id = Column(Integer, primary_key=True, index=True)
    wish_id = Column(Integer, ForeignKey("wishes.id"), nullable=False)
    verifier_user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    status = Column(SQLEnum(VerificationStatus), default=VerificationStatus.PENDING, nullable=False)
    comment = Column(Text, nullable=True)  # Verifier's comment
    dispute_reason = Column(Text, nullable=True)  # Why they disputed
    verifier_reply_to_owner = Column(Text, nullable=True)  # Verifier's reply after owner responds to dispute
    proof_url = Column(String, nullable=True)  # Optional evidence link
    created_at = Column(DateTime, default=lambda: datetime.now(timezone.utc))
    verified_at = Column(DateTime, nullable=True)  # When they made their decision
    
    # Relationships
    wish = relationship("Wish", back_populates="completion_verifications")
    verifier = relationship("User", foreign_keys=[verifier_user_id])

    def __repr__(self):
        return f"<CompletionVerification wish_id={self.wish_id} verifier={self.verifier_user_id} status={self.status}>"

