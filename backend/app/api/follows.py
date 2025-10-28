from fastapi import APIRouter, Depends, HTTPException, status, Header
from sqlalchemy.orm import Session
from sqlalchemy import func
from typing import Optional
from app.database import get_db
from app.models.user import User
from app.models.follow import Follow
from app.models.notification import Notification
from app.api.users import get_current_user_from_token
from datetime import datetime, timezone

router = APIRouter()

def get_current_user_from_header(authorization: Optional[str] = Header(None), db: Session = Depends(get_db)) -> User:
    """Helper to get current user from Authorization header"""
    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(status_code=401, detail="Not authenticated")
    
    token = authorization.replace("Bearer ", "")
    return get_current_user_from_token(token, db)

@router.post("/{user_id}/follow")
def follow_user(
    user_id: int,
    current_user: User = Depends(get_current_user_from_header),
    db: Session = Depends(get_db)
):
    """Follow a user"""
    # Can't follow yourself
    if user_id == current_user.id:
        raise HTTPException(status_code=400, detail="You cannot follow yourself")
    
    # Check if user exists
    target_user = db.query(User).filter(User.id == user_id).first()
    if not target_user:
        raise HTTPException(status_code=404, detail="User not found")
    
    # Check if already following
    existing_follow = db.query(Follow).filter(
        Follow.follower_id == current_user.id,
        Follow.following_id == user_id
    ).first()
    
    if existing_follow:
        raise HTTPException(status_code=400, detail="Already following this user")
    
    # Create follow relationship
    new_follow = Follow(
        follower_id=current_user.id,
        following_id=user_id
    )
    db.add(new_follow)
    
    # Create notification for the followed user
    notification = Notification(
        user_id=user_id,  # The user being followed receives the notification
        actor_id=current_user.id,  # The user who followed
        type="follow",
        content=f"{current_user.username} started following you",
        is_read=False,
        created_at=datetime.now(timezone.utc)
    )
    db.add(notification)
    
    db.commit()
    
    return {"message": "Successfully followed user", "following": True}

@router.delete("/{user_id}/follow")
def unfollow_user(
    user_id: int,
    current_user: User = Depends(get_current_user_from_header),
    db: Session = Depends(get_db)
):
    """Unfollow a user"""
    follow = db.query(Follow).filter(
        Follow.follower_id == current_user.id,
        Follow.following_id == user_id
    ).first()
    
    if not follow:
        raise HTTPException(status_code=404, detail="You are not following this user")
    
    db.delete(follow)
    db.commit()
    
    return {"message": "Successfully unfollowed user", "following": False}

@router.get("/{user_id}/followers")
def get_user_followers(
    user_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user_from_header)
):
    """Get list of users following the specified user"""
    followers = db.query(Follow).filter(Follow.following_id == user_id).all()
    
    result = []
    for follow in followers:
        follower = db.query(User).filter(User.id == follow.follower_id).first()
        if follower:
            result.append({
                "id": follower.id,
                "username": follower.username,
                "email": follower.email
            })
    
    return result

@router.get("/{user_id}/following")
def get_user_following(
    user_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user_from_header)
):
    """Get list of users that the specified user is following"""
    following = db.query(Follow).filter(Follow.follower_id == user_id).all()
    
    result = []
    for follow in following:
        followed_user = db.query(User).filter(User.id == follow.following_id).first()
        if followed_user:
            result.append({
                "id": followed_user.id,
                "username": followed_user.username,
                "email": followed_user.email
            })
    
    return result

@router.get("/{user_id}/is-following")
def check_following_status(
    user_id: int,
    current_user: User = Depends(get_current_user_from_header),
    db: Session = Depends(get_db)
):
    """Check if current user is following the specified user"""
    follow = db.query(Follow).filter(
        Follow.follower_id == current_user.id,
        Follow.following_id == user_id
    ).first()
    
    followers_count = db.query(func.count(Follow.id)).filter(Follow.following_id == user_id).scalar() or 0
    following_count = db.query(func.count(Follow.id)).filter(Follow.follower_id == user_id).scalar() or 0
    
    return {
        "is_following": follow is not None,
        "followers_count": followers_count,
        "following_count": following_count
    }

