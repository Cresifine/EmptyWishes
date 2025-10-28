from fastapi import APIRouter, HTTPException, status, Depends, Header
from sqlalchemy.orm import Session
from typing import List, Optional
from datetime import datetime, timezone

from app.database import get_db
from app.models.completion_verification import CompletionVerification, VerificationStatus
from app.models.wish import Wish, CompletionStatus
from app.models.user import User
from app.api.users import get_current_user_from_token
from app.api.notifications import create_notification

router = APIRouter()

def ensure_utc(dt):
    """Ensure datetime is timezone-aware UTC"""
    if dt is None:
        return None
    if dt.tzinfo is None:
        return dt.replace(tzinfo=timezone.utc)
    return dt


@router.post("/wishes/{wish_id}/request-verification")
def request_completion_verification(
    wish_id: int,
    verifier_user_ids: List[int],
    authorization: Optional[str] = Header(None),
    db: Session = Depends(get_db)
):
    """
    Request completion verification from specific users.
    Can only be called by the wish owner when marking goal as complete.
    """
    # Get current user
    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(status_code=401, detail="Not authenticated")
    
    token = authorization.replace("Bearer ", "")
    current_user = get_current_user_from_token(token, db)
    
    # Get the wish
    wish = db.query(Wish).filter(Wish.id == wish_id).first()
    if not wish:
        raise HTTPException(status_code=404, detail="Goal not found")
    
    # Check ownership
    if wish.user_id != current_user.id:
        raise HTTPException(status_code=403, detail="Only goal owner can request verification")
    
    # Check if verifiers already exist (can't change verifiers after creation)
    existing_verifications = db.query(CompletionVerification).filter(
        CompletionVerification.wish_id == wish_id
    ).count()
    
    if existing_verifications > 0:
        raise HTTPException(
            status_code=400,
            detail="Verifiers have already been set and cannot be changed"
        )
    
    # Validate verifiers
    if len(verifier_user_ids) == 0:
        raise HTTPException(status_code=400, detail="At least one verifier is required")
    
    if len(verifier_user_ids) > 10:
        raise HTTPException(status_code=400, detail="Maximum 10 verifiers allowed")
    
    # Remove duplicates
    verifier_user_ids = list(set(verifier_user_ids))
    
    # Check that verifiers exist
    verifiers = db.query(User).filter(User.id.in_(verifier_user_ids)).all()
    if len(verifiers) != len(verifier_user_ids):
        raise HTTPException(status_code=400, detail="One or more verifier users not found")
    
    # Can't verify your own goal
    if current_user.id in verifier_user_ids:
        raise HTTPException(status_code=400, detail="You cannot verify your own goal")
    
    # Create verification records
    verifications = []
    for verifier_id in verifier_user_ids:
        verification = CompletionVerification(
            wish_id=wish_id,
            verifier_user_id=verifier_id,
            status=VerificationStatus.PENDING
        )
        db.add(verification)
        verifications.append(verification)
        
        # Send notification to verifier
        create_notification(
            db=db,
            user_id=verifier_id,
            actor_id=current_user.id,
            notification_type="verification_request",
            wish_id=wish_id,
            content=f"{current_user.username} has selected you to verify their goal: {wish.title}"
        )
    
    # Update wish
    wish.requires_verification = True
    wish.completion_status = CompletionStatus.PENDING_VERIFICATION
    
    db.commit()
    
    return {
        "message": "Verification requested",
        "verifiers_count": len(verifications),
        "verifiers": [
            {
                "id": v.verifier_user_id,
                "username": db.query(User).filter(User.id == v.verifier_user_id).first().username
            }
            for v in verifications
        ]
    }


@router.post("/wishes/{wish_id}/verify")
def verify_completion(
    wish_id: int,
    approved: bool,
    comment: Optional[str] = None,
    dispute_reason: Optional[str] = None,
    authorization: Optional[str] = Header(None),
    db: Session = Depends(get_db)
):
    """
    Verify or dispute a goal's completion.
    Can only be called by designated verifiers.
    """
    # Get current user
    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(status_code=401, detail="Not authenticated")
    
    token = authorization.replace("Bearer ", "")
    current_user = get_current_user_from_token(token, db)
    
    # Get the wish
    wish = db.query(Wish).filter(Wish.id == wish_id).first()
    if not wish:
        raise HTTPException(status_code=404, detail="Goal not found")
    
    # Check if user is a designated verifier
    verification = db.query(CompletionVerification).filter(
        CompletionVerification.wish_id == wish_id,
        CompletionVerification.verifier_user_id == current_user.id
    ).first()
    
    if not verification:
        raise HTTPException(
            status_code=403,
            detail="You are not a designated verifier for this goal"
        )
    
    # Check if already verified
    if verification.status != VerificationStatus.PENDING:
        raise HTTPException(
            status_code=400,
            detail=f"You have already {verification.status.value} this goal"
        )
    
    # Update verification
    verification.status = VerificationStatus.APPROVED if approved else VerificationStatus.DISPUTED
    verification.comment = comment
    verification.dispute_reason = dispute_reason if not approved else None
    verification.verified_at = datetime.now(timezone.utc)
    
    # Check if all verifiers have responded
    all_verifications = db.query(CompletionVerification).filter(
        CompletionVerification.wish_id == wish_id
    ).all()
    
    all_responded = all(v.status != VerificationStatus.PENDING for v in all_verifications)
    
    if all_responded:
        # Check for consensus
        all_approved = all(v.status == VerificationStatus.APPROVED for v in all_verifications)
        any_disputed = any(v.status == VerificationStatus.DISPUTED for v in all_verifications)
        
        if all_approved:
            wish.completion_status = CompletionStatus.VERIFIED
            wish.status = "completed"
            wish.is_completed = True
        elif any_disputed:
            wish.completion_status = CompletionStatus.DISPUTED
        
        # Notify goal owner
        owner = db.query(User).filter(User.id == wish.user_id).first()
        if owner:
            if all_approved:
                notification_content = f"Your goal '{wish.title}' has been verified by all verifiers!"
            else:
                disputed_count = sum(1 for v in all_verifications if v.status == VerificationStatus.DISPUTED)
                notification_content = f"Your goal '{wish.title}' has {disputed_count} dispute(s). You can respond to disputes."
            
            create_notification(
                db=db,
                user_id=wish.user_id,
                actor_id=current_user.id,
                notification_type="verification_complete",
                wish_id=wish_id,
                content=notification_content
            )
    else:
        # Notify owner of partial verification
        create_notification(
            db=db,
            user_id=wish.user_id,
            actor_id=current_user.id,
            notification_type="verification_response",
            wish_id=wish_id,
            content=f"{current_user.username} has {'approved' if approved else 'disputed'} your goal completion"
        )
    
    db.commit()
    db.refresh(wish)
    db.refresh(verification)
    
    return {
        "message": "Verification recorded",
        "status": verification.status.value,
        "wish_completion_status": wish.completion_status.value,
        "all_verified": all_responded and all_approved if all_responded else False
    }


@router.post("/wishes/{wish_id}/respond-to-dispute")
def respond_to_dispute(
    wish_id: int,
    response: str,
    authorization: Optional[str] = Header(None),
    db: Session = Depends(get_db)
):
    """
    Owner responds to disputes with explanation/additional proof.
    """
    # Get current user
    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(status_code=401, detail="Not authenticated")
    
    token = authorization.replace("Bearer ", "")
    current_user = get_current_user_from_token(token, db)
    
    # Get the wish
    wish = db.query(Wish).filter(Wish.id == wish_id).first()
    if not wish:
        raise HTTPException(status_code=404, detail="Goal not found")
    
    # Check ownership
    if wish.user_id != current_user.id:
        raise HTTPException(status_code=403, detail="Only goal owner can respond to disputes")
    
    # Check if there are any disputes
    disputed = db.query(CompletionVerification).filter(
        CompletionVerification.wish_id == wish_id,
        CompletionVerification.status == VerificationStatus.DISPUTED
    ).count()
    
    if disputed == 0:
        raise HTTPException(status_code=400, detail="No disputes to respond to")
    
    # Save response
    wish.owner_dispute_response = response
    
    # Notify verifiers who disputed
    disputed_verifications = db.query(CompletionVerification).filter(
        CompletionVerification.wish_id == wish_id,
        CompletionVerification.status == VerificationStatus.DISPUTED
    ).all()
    
    for verification in disputed_verifications:
        create_notification(
            db=db,
            user_id=verification.verifier_user_id,
            actor_id=current_user.id,
            notification_type="dispute_response",
            wish_id=wish_id,
            content=f"{current_user.username} has responded to your dispute on '{wish.title}'"
        )
    
    db.commit()
    
    return {
        "message": "Response sent to verifiers",
        "disputed_count": len(disputed_verifications)
    }


@router.post("/wishes/{wish_id}/re-request-verification")
def re_request_verification(
    wish_id: int,
    authorization: Optional[str] = Header(None),
    db: Session = Depends(get_db)
):
    """
    Reset disputed verifications back to pending status.
    Owner can call this after responding to disputes to request another review.
    """
    # Get current user
    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(status_code=401, detail="Not authenticated")
    
    token = authorization.replace("Bearer ", "")
    current_user = get_current_user_from_token(token, db)
    
    # Get the wish
    wish = db.query(Wish).filter(Wish.id == wish_id).first()
    if not wish:
        raise HTTPException(status_code=404, detail="Goal not found")
    
    # Check ownership
    if wish.user_id != current_user.id:
        raise HTTPException(status_code=403, detail="Only goal owner can re-request verification")
    
    # Check if there are any disputed verifications
    disputed_verifications = db.query(CompletionVerification).filter(
        CompletionVerification.wish_id == wish_id,
        CompletionVerification.status == VerificationStatus.DISPUTED
    ).all()
    
    if not disputed_verifications:
        raise HTTPException(status_code=400, detail="No disputed verifications to reset")
    
    # Reset disputed verifications to pending
    for verification in disputed_verifications:
        verification.status = VerificationStatus.PENDING
        verification.verified_at = None
        
        # Notify verifier that owner has addressed concerns
        create_notification(
            db=db,
            user_id=verification.verifier_user_id,
            actor_id=current_user.id,
            notification_type="verification_ready",
            wish_id=wish_id,
            content=f"{current_user.username} has addressed your concerns. Please review '{wish.title}' again."
        )
    
    # Update wish status back to pending verification
    wish.completion_status = CompletionStatus.PENDING_VERIFICATION
    
    db.commit()
    
    return {
        "message": "Verification re-requested successfully",
        "reset_count": len(disputed_verifications)
    }


@router.post("/wishes/{wish_id}/verifications/{verification_id}/reply")
def verifier_reply_to_owner(
    wish_id: int,
    verification_id: int,
    reply: str,
    authorization: Optional[str] = Header(None),
    db: Session = Depends(get_db)
):
    """
    Verifier replies to owner's dispute response.
    This allows back-and-forth conversation between owner and verifier.
    """
    # Get current user
    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(status_code=401, detail="Not authenticated")
    
    token = authorization.replace("Bearer ", "")
    current_user = get_current_user_from_token(token, db)
    
    # Get the verification
    verification = db.query(CompletionVerification).filter(
        CompletionVerification.id == verification_id,
        CompletionVerification.wish_id == wish_id
    ).first()
    
    if not verification:
        raise HTTPException(status_code=404, detail="Verification not found")
    
    # Check if current user is the verifier
    if verification.verifier_user_id != current_user.id:
        raise HTTPException(status_code=403, detail="Only the verifier can reply")
    
    # Update the verifier's reply
    verification.verifier_reply_to_owner = reply
    
    # Notify the owner
    wish = db.query(Wish).filter(Wish.id == wish_id).first()
    if wish:
        create_notification(
            db=db,
            user_id=wish.user_id,
            actor_id=current_user.id,
            notification_type="dispute_response",
            wish_id=wish_id,
            content=f"{current_user.username} replied to your dispute response for '{wish.title}'"
        )
    
    db.commit()
    
    return {
        "message": "Reply sent successfully",
        "verification_id": verification_id
    }


@router.get("/wishes/{wish_id}/verifications")
def get_verifications(
    wish_id: int,
    authorization: Optional[str] = Header(None),
    db: Session = Depends(get_db)
):
    """
    Get all verification records for a goal.
    """
    # Get the wish
    wish = db.query(Wish).filter(Wish.id == wish_id).first()
    if not wish:
        raise HTTPException(status_code=404, detail="Goal not found")
    
    # Get verifications
    verifications = db.query(CompletionVerification).filter(
        CompletionVerification.wish_id == wish_id
    ).all()
    
    result = []
    for v in verifications:
        verifier = db.query(User).filter(User.id == v.verifier_user_id).first()
        result.append({
            "id": v.id,
            "verifier": {
                "id": verifier.id,
                "username": verifier.username
            },
            "status": v.status.value,
            "comment": v.comment,
            "dispute_reason": v.dispute_reason,
            "verifier_reply_to_owner": v.verifier_reply_to_owner,
            "verified_at": ensure_utc(v.verified_at).isoformat() if v.verified_at else None,
            "created_at": ensure_utc(v.created_at).isoformat()
        })
    
    approved_count = sum(1 for v in verifications if v.status == VerificationStatus.APPROVED)
    disputed_count = sum(1 for v in verifications if v.status == VerificationStatus.DISPUTED)
    pending_count = sum(1 for v in verifications if v.status == VerificationStatus.PENDING)
    
    return {
        "verifications": result,
        "summary": {
            "total": len(verifications),
            "approved": approved_count,
            "disputed": disputed_count,
            "pending": pending_count
        },
        "completion_status": wish.completion_status.value,
        "owner_dispute_response": wish.owner_dispute_response
    }

