from fastapi import APIRouter, HTTPException, status, Depends, Header
from sqlalchemy.orm import Session
from typing import List, Optional
from datetime import datetime, timezone
from app.schemas.milestone import MilestoneCreate, MilestoneUpdate, Milestone as MilestoneSchema
from app.database import get_db
from app.models.milestone import Milestone
from app.models.wish import Wish
from app.api.users import get_current_user_from_token

router = APIRouter()


@router.post("/api/wishes/{wish_id}/milestones", response_model=MilestoneSchema, status_code=status.HTTP_201_CREATED)
async def create_milestone(
    wish_id: int,
    milestone: MilestoneCreate,
    authorization: Optional[str] = Header(None),
    db: Session = Depends(get_db)
):
    """Create a new milestone for a wish"""
    # Verify wish exists and user has access
    wish = db.query(Wish).filter(Wish.id == wish_id).first()
    if not wish:
        raise HTTPException(status_code=404, detail="Wish not found")
    
    # Check authorization if provided
    if authorization and authorization.startswith("Bearer "):
        token = authorization.replace("Bearer ", "")
        try:
            user = get_current_user_from_token(token, db)
            if wish.user_id != user.id:
                raise HTTPException(status_code=403, detail="Not authorized to add milestones to this wish")
        except:
            pass
    
    # Create milestone
    db_milestone = Milestone(
        wish_id=wish_id,
        title=milestone.title,
        description=milestone.description,
        order_index=milestone.order_index,
        target_date=milestone.target_date
    )
    db.add(db_milestone)
    db.commit()
    db.refresh(db_milestone)
    
    # Update wish progress based on milestones
    _update_wish_progress(wish, db)
    
    return db_milestone


@router.get("/api/wishes/{wish_id}/milestones", response_model=List[MilestoneSchema])
async def get_milestones(
    wish_id: int,
    db: Session = Depends(get_db)
):
    """Get all milestones for a wish"""
    wish = db.query(Wish).filter(Wish.id == wish_id).first()
    if not wish:
        raise HTTPException(status_code=404, detail="Wish not found")
    
    milestones = db.query(Milestone).filter(
        Milestone.wish_id == wish_id
    ).order_by(Milestone.order_index).all()
    
    return milestones


@router.patch("/api/milestones/{milestone_id}", response_model=MilestoneSchema)
async def update_milestone(
    milestone_id: int,
    milestone_update: MilestoneUpdate,
    authorization: Optional[str] = Header(None),
    db: Session = Depends(get_db)
):
    """Update a milestone"""
    db_milestone = db.query(Milestone).filter(Milestone.id == milestone_id).first()
    if not db_milestone:
        raise HTTPException(status_code=404, detail="Milestone not found")
    
    # Check authorization
    wish = db.query(Wish).filter(Wish.id == db_milestone.wish_id).first()
    if authorization and authorization.startswith("Bearer "):
        token = authorization.replace("Bearer ", "")
        try:
            user = get_current_user_from_token(token, db)
            if wish.user_id != user.id:
                raise HTTPException(status_code=403, detail="Not authorized to update this milestone")
        except:
            pass
    
    # Update fields
    update_data = milestone_update.model_dump(exclude_unset=True)
    for field, value in update_data.items():
        setattr(db_milestone, field, value)
    
    # If marking as completed, set completed_at
    if milestone_update.is_completed is not None:
        if milestone_update.is_completed and not db_milestone.completed_at:
            db_milestone.completed_at = datetime.now(timezone.utc)
        elif not milestone_update.is_completed:
            db_milestone.completed_at = None
    
    db.commit()
    db.refresh(db_milestone)
    
    # Update wish progress
    _update_wish_progress(wish, db)
    
    return db_milestone


@router.delete("/api/milestones/{milestone_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_milestone(
    milestone_id: int,
    authorization: Optional[str] = Header(None),
    db: Session = Depends(get_db)
):
    """Delete a milestone"""
    db_milestone = db.query(Milestone).filter(Milestone.id == milestone_id).first()
    if not db_milestone:
        raise HTTPException(status_code=404, detail="Milestone not found")
    
    # Check authorization
    wish = db.query(Wish).filter(Wish.id == db_milestone.wish_id).first()
    if authorization and authorization.startswith("Bearer "):
        token = authorization.replace("Bearer ", "")
        try:
            user = get_current_user_from_token(token, db)
            if wish.user_id != user.id:
                raise HTTPException(status_code=403, detail="Not authorized to delete this milestone")
        except:
            pass
    
    db.delete(db_milestone)
    db.commit()
    
    # Update wish progress
    _update_wish_progress(wish, db)
    
    return None


def _update_wish_progress(wish: Wish, db: Session):
    """Calculate and update wish progress based on completed milestones (weighted by points)"""
    from app.models.wish import CompletionStatus
    from app.models.completion_verification import CompletionVerification
    from app.models.user import User
    from app.api.notifications import create_notification
    
    if wish.progress_mode != "milestone":
        return
    
    milestones = db.query(Milestone).filter(Milestone.wish_id == wish.id).all()
    if not milestones:
        return
    
    # Calculate progress based on points (weighted)
    total_points = sum(m.points for m in milestones)
    completed_points = sum(m.points for m in milestones if m.is_completed)
    
    if total_points == 0:
        new_progress = 0
    else:
        new_progress = int((completed_points / total_points) * 100)
    
    old_progress = wish.progress
    wish.progress = new_progress
    
    # Auto-complete wish if all milestones done (100%)
    if new_progress >= 100 and old_progress < 100:
        if wish.requires_verification:
            # If verification is required, set status to pending verification
            wish.completion_status = CompletionStatus.PENDING_VERIFICATION
            # Don't mark as completed yet - wait for verification
            print(f"[milestones] Wish {wish.id} reached 100% - pending verification")
            
            # Notify all verifiers
            verifications = db.query(CompletionVerification).filter(
                CompletionVerification.wish_id == wish.id
            ).all()
            
            wish_owner = db.query(User).filter(User.id == wish.user_id).first()
            for verification in verifications:
                try:
                    create_notification(
                        db=db,
                        user_id=verification.verifier_user_id,
                        actor_id=wish.user_id,
                        notification_type="verification_ready",
                        wish_id=wish.id,
                        content=f"{wish_owner.username if wish_owner else 'Someone'} has completed their goal '{wish.title}' and needs your verification!"
                    )
                except Exception as e:
                    print(f"[milestones] Failed to notify verifier {verification.verifier_user_id}: {e}")
        else:
            # No verification required - mark as completed
            wish.status = "completed"
            wish.is_completed = True
            wish.completion_status = CompletionStatus.SELF_VERIFIED
            print(f"[milestones] Wish {wish.id} reached 100% - auto-completed (no verification required)")
    
    db.commit()

