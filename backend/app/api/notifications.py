from fastapi import APIRouter, HTTPException, status, Depends, Header
from sqlalchemy.orm import Session
from sqlalchemy import func, or_, and_
from typing import Optional, List
from datetime import datetime, timedelta
import json
from app.database import get_db
from app.models.notification import Notification
from app.models.user import User
from app.models.wish import Wish
from app.api.users import get_current_user_from_token

router = APIRouter()

AGGREGATION_THRESHOLD = 3  # Aggregate if more than this many notifications
AGGREGATION_WINDOW_HOURS = 24  # Aggregate within this time window

def create_notification(
    db: Session,
    user_id: int,
    notification_type: str,
    wish_id: int,
    actor_id: int,
    content: Optional[str] = None
):
    """Create a notification with smart aggregation"""
    
    # Don't notify yourself
    if user_id == actor_id:
        return None
    
    # Check for existing notifications to aggregate
    time_threshold = datetime.utcnow() - timedelta(hours=AGGREGATION_WINDOW_HOURS)
    
    existing = db.query(Notification).filter(
        Notification.user_id == user_id,
        Notification.wish_id == wish_id,
        Notification.type.in_([notification_type, f"{notification_type}_aggregated"]),
        Notification.created_at >= time_threshold
    ).first()
    
    if existing:
        # Update existing notification
        if existing.type == f"{notification_type}_aggregated":
            # Already aggregated, add to list
            actor_ids = json.loads(existing.actor_ids) if existing.actor_ids else []
            if actor_id not in actor_ids:
                actor_ids.append(actor_id)
                existing.actor_ids = json.dumps(actor_ids)
                existing.updated_at = datetime.utcnow()
                existing.is_read = False  # Mark as unread again
                db.commit()
        else:
            # Check if we should start aggregating
            count = db.query(func.count(Notification.id)).filter(
                Notification.user_id == user_id,
                Notification.wish_id == wish_id,
                Notification.type == notification_type,
                Notification.created_at >= time_threshold
            ).scalar()
            
            if count >= AGGREGATION_THRESHOLD:
                # Convert to aggregated notification
                existing.type = f"{notification_type}_aggregated"
                existing.actor_ids = json.dumps([existing.actor_id, actor_id])
                existing.actor_id = None
                existing.updated_at = datetime.utcnow()
                existing.is_read = False
                db.commit()
            else:
                # Create new individual notification
                new_notif = Notification(
                    user_id=user_id,
                    type=notification_type,
                    wish_id=wish_id,
                    actor_id=actor_id,
                    content=content
                )
                db.add(new_notif)
                db.commit()
    else:
        # Create new notification
        new_notif = Notification(
            user_id=user_id,
            type=notification_type,
            wish_id=wish_id,
            actor_id=actor_id,
            content=content
        )
        db.add(new_notif)
        db.commit()
    
    return True

@router.get("/")
def get_notifications(
    authorization: Optional[str] = Header(None),
    db: Session = Depends(get_db)
):
    """Get all notifications for the current user"""
    # Get current user
    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(status_code=401, detail="Not authenticated")
    
    token = authorization.replace("Bearer ", "")
    try:
        user = get_current_user_from_token(token, db)
    except:
        raise HTTPException(status_code=401, detail="Invalid token")
    
    # Get notifications
    notifications = db.query(Notification).filter(
        Notification.user_id == user.id
    ).order_by(Notification.updated_at.desc()).limit(50).all()
    
    # Enrich notifications with user and wish data
    result = []
    for notif in notifications:
        notif_data = {
            "id": notif.id,
            "type": notif.type,
            "wish_id": notif.wish_id,
            "content": notif.content,
            "is_read": notif.is_read,
            "created_at": notif.created_at.isoformat(),
            "updated_at": notif.updated_at.isoformat(),
        }
        
        # Get wish info
        if notif.wish_id:
            wish = db.query(Wish).filter(Wish.id == notif.wish_id).first()
            if wish:
                notif_data["wish_title"] = wish.title
        
        # Get actor info
        if notif.actor_id:
            actor = db.query(User).filter(User.id == notif.actor_id).first()
            if actor:
                notif_data["actor_username"] = actor.username
                notif_data["actor_id"] = actor.id
        
        # Get aggregated actors
        if notif.actor_ids:
            actor_ids = json.loads(notif.actor_ids)
            actors = db.query(User).filter(User.id.in_(actor_ids)).all()
            notif_data["actor_usernames"] = [a.username for a in actors]
            notif_data["count"] = len(actor_ids)
        
        result.append(notif_data)
    
    return result

@router.get("/unread-count")
def get_unread_count(
    authorization: Optional[str] = Header(None),
    db: Session = Depends(get_db)
):
    """Get count of unread notifications"""
    # Get current user
    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(status_code=401, detail="Not authenticated")
    
    token = authorization.replace("Bearer ", "")
    try:
        user = get_current_user_from_token(token, db)
    except:
        raise HTTPException(status_code=401, detail="Invalid token")
    
    count = db.query(func.count(Notification.id)).filter(
        Notification.user_id == user.id,
        Notification.is_read == False
    ).scalar()
    
    return {"unread_count": count or 0}

@router.post("/{notification_id}/read")
def mark_as_read(
    notification_id: int,
    authorization: Optional[str] = Header(None),
    db: Session = Depends(get_db)
):
    """Mark a notification as read"""
    # Get current user
    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(status_code=401, detail="Not authenticated")
    
    token = authorization.replace("Bearer ", "")
    try:
        user = get_current_user_from_token(token, db)
    except:
        raise HTTPException(status_code=401, detail="Invalid token")
    
    notif = db.query(Notification).filter(
        Notification.id == notification_id,
        Notification.user_id == user.id
    ).first()
    
    if not notif:
        raise HTTPException(status_code=404, detail="Notification not found")
    
    notif.is_read = True
    db.commit()
    
    return {"message": "Marked as read"}

@router.post("/read-all")
def mark_all_as_read(
    authorization: Optional[str] = Header(None),
    db: Session = Depends(get_db)
):
    """Mark all notifications as read"""
    # Get current user
    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(status_code=401, detail="Not authenticated")
    
    token = authorization.replace("Bearer ", "")
    try:
        user = get_current_user_from_token(token, db)
    except:
        raise HTTPException(status_code=401, detail="Invalid token")
    
    db.query(Notification).filter(
        Notification.user_id == user.id,
        Notification.is_read == False
    ).update({"is_read": True})
    
    db.commit()
    
    return {"message": "All notifications marked as read"}

