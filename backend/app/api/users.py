from fastapi import APIRouter, Depends, HTTPException, status, Query
from sqlalchemy.orm import Session
from sqlalchemy import func
from jose import JWTError, jwt
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from typing import List, Optional
from pydantic import BaseModel, EmailStr
from app.schemas.user import UserResponse
from app.database import get_db
from app.models.user import User
from app.models.wish import Wish
from app.core.config import settings
from app.core.security import get_password_hash, verify_password

router = APIRouter()
security = HTTPBearer()

class UserUpdate(BaseModel):
    username: Optional[str] = None
    email: Optional[EmailStr] = None
    current_password: Optional[str] = None
    new_password: Optional[str] = None
    instagram: Optional[str] = None
    twitter: Optional[str] = None
    linkedin: Optional[str] = None
    github: Optional[str] = None

def get_current_user_from_token(token: str, db: Session) -> User:
    try:
        payload = jwt.decode(token, settings.SECRET_KEY, algorithms=[settings.ALGORITHM])
        email: str = payload.get("sub")
        if email is None:
            raise HTTPException(status_code=401, detail="Invalid authentication credentials")
    except JWTError:
        raise HTTPException(status_code=401, detail="Invalid authentication credentials")
    
    user = db.query(User).filter(User.email == email).first()
    if user is None:
        raise HTTPException(status_code=401, detail="User not found")
    return user

def get_current_user_from_credentials(
    credentials: HTTPAuthorizationCredentials = Depends(security),
    db: Session = Depends(get_db)
) -> User:
    return get_current_user_from_token(credentials.credentials, db)

@router.get("/me")
def get_current_user(
    current_user: User = Depends(get_current_user_from_credentials),
    db: Session = Depends(get_db)
):
    # Calculate statistics
    all_wishes = db.query(Wish).filter(Wish.user_id == current_user.id).all()
    total_wishes = len(all_wishes)
    completed_wishes = len([w for w in all_wishes if w.status == "completed"])
    
    # Calculate average progress
    if total_wishes > 0:
        avg_progress = sum(w.progress for w in all_wishes) / total_wishes
    else:
        avg_progress = 0
    
    # Calculate streak (simplified - days with progress updates)
    current_streak = 0  # TODO: Implement proper streak calculation
    
    return {
        "id": current_user.id,
        "username": current_user.username,
        "email": current_user.email,
        "instagram": current_user.instagram,
        "twitter": current_user.twitter,
        "linkedin": current_user.linkedin,
        "github": current_user.github,
        "statistics": {
            "total_wishes": total_wishes,
            "completed_wishes": completed_wishes,
            "average_progress": round(avg_progress, 1),
            "current_streak": current_streak
        }
    }

@router.put("/me")
def update_profile(
    user_update: UserUpdate,
    current_user: User = Depends(get_current_user_from_credentials),
    db: Session = Depends(get_db)
):
    """Update current user's profile"""
    # Check if username is taken by another user
    if user_update.username and user_update.username != current_user.username:
        existing_user = db.query(User).filter(User.username == user_update.username).first()
        if existing_user:
            raise HTTPException(status_code=400, detail="Username already taken")
        current_user.username = user_update.username
    
    # Check if email is taken by another user
    if user_update.email and user_update.email != current_user.email:
        existing_user = db.query(User).filter(User.email == user_update.email).first()
        if existing_user:
            raise HTTPException(status_code=400, detail="Email already taken")
        current_user.email = user_update.email
    
    # Update password if requested
    if user_update.new_password:
        if not user_update.current_password:
            raise HTTPException(status_code=400, detail="Current password required to set new password")
        
        if not verify_password(user_update.current_password, current_user.hashed_password):
            raise HTTPException(status_code=400, detail="Current password is incorrect")
        
        current_user.hashed_password = get_password_hash(user_update.new_password)
    
    # Update social media links
    if user_update.instagram is not None:
        current_user.instagram = user_update.instagram if user_update.instagram else None
    if user_update.twitter is not None:
        current_user.twitter = user_update.twitter if user_update.twitter else None
    if user_update.linkedin is not None:
        current_user.linkedin = user_update.linkedin if user_update.linkedin else None
    if user_update.github is not None:
        current_user.github = user_update.github if user_update.github else None
    
    db.commit()
    db.refresh(current_user)
    
    return {
        "id": current_user.id,
        "username": current_user.username,
        "email": current_user.email,
        "instagram": current_user.instagram,
        "twitter": current_user.twitter,
        "linkedin": current_user.linkedin,
        "github": current_user.github,
        "message": "Profile updated successfully"
    }

@router.get("/search")
def search_users(
    q: str = Query(..., min_length=1),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user_from_credentials)
):
    """Search for users by username or email"""
    users = db.query(User).filter(
        (User.username.contains(q)) | (User.email.contains(q))
    ).filter(User.id != current_user.id).limit(10).all()
    
    return [
        {
            "id": user.id,
            "username": user.username,
            "email": user.email
        }
        for user in users
    ]

@router.get("/{user_id}")
def get_user_profile(
    user_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user_from_credentials)
):
    """Get another user's public profile including their statistics and public goals"""
    user = db.query(User).filter(User.id == user_id).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    
    # Calculate statistics for this user
    all_wishes = db.query(Wish).filter(Wish.user_id == user.id).all()
    total_wishes = len(all_wishes)
    completed_wishes = len([w for w in all_wishes if w.status == "completed"])
    
    # Calculate average progress
    if total_wishes > 0:
        avg_progress = sum(w.progress for w in all_wishes) / total_wishes
    else:
        avg_progress = 0
    
    # Get only current wishes (not archived/missed) for display
    current_wishes = [w for w in all_wishes if w.status == "current"]
    
    return {
        "id": user.id,
        "username": user.username,
        "email": user.email,
        "statistics": {
            "total_wishes": total_wishes,
            "completed_wishes": completed_wishes,
            "average_progress": round(avg_progress, 1),
            "current_streak": 0  # TODO: Implement proper streak calculation
        },
        "wishes": [
            {
                "id": w.id,
                "title": w.title,
                "description": w.description,
                "progress": w.progress,
                "is_completed": w.is_completed,
                "status": w.status,
                "created_at": w.created_at.isoformat(),
                "target_date": w.target_date.isoformat() if w.target_date else None,
                "consequence": w.consequence,
                "cover_image": w.cover_image
            }
            for w in current_wishes
        ]
    }

@router.get("/{user_id}/stats")
def get_user_stats(
    user_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user_from_credentials)
):
    """Get another user's statistics"""
    user = db.query(User).filter(User.id == user_id).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    
    # Calculate statistics for this user
    all_wishes = db.query(Wish).filter(Wish.user_id == user.id).all()
    total_wishes = len(all_wishes)
    completed_wishes = len([w for w in all_wishes if w.status == "completed"])
    
    # Calculate average progress
    if total_wishes > 0:
        avg_progress = sum(w.progress for w in all_wishes) / total_wishes
    else:
        avg_progress = 0
    
    return {
        "total_wishes": total_wishes,
        "completed_wishes": completed_wishes,
        "average_progress": round(avg_progress, 1),
        "current_streak": 0  # TODO: Implement proper streak calculation
    }

@router.get("/{user_id}/wishes")
def get_user_wishes(
    user_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user_from_credentials)
):
    """Get another user's public wishes"""
    user = db.query(User).filter(User.id == user_id).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    
    # Get only current and completed wishes (not archived/missed) for display
    wishes = db.query(Wish).filter(
        Wish.user_id == user.id,
        Wish.status.in_(["current", "completed"])
    ).all()
    
    return [
        {
            "id": w.id,
            "user_id": w.user_id,
            "title": w.title,
            "description": w.description,
            "progress": w.progress,
            "is_completed": w.is_completed,
            "status": w.status,
            "created_at": w.created_at.isoformat(),
            "target_date": w.target_date.isoformat() if w.target_date else None,
            "consequence": w.consequence,
            "cover_image": w.cover_image,
            "tags": [{"id": tag.id, "name": tag.name} for tag in w.tags]
        }
        for w in wishes
    ]

