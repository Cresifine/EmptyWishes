from fastapi import APIRouter, Depends, HTTPException, status, Query
from sqlalchemy.orm import Session
from sqlalchemy import func
from jose import JWTError, jwt
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from typing import List
from app.schemas.user import UserResponse
from app.database import get_db
from app.models.user import User
from app.models.wish import Wish
from app.core.config import settings

router = APIRouter()
security = HTTPBearer()

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
        "statistics": {
            "total_wishes": total_wishes,
            "completed_wishes": completed_wishes,
            "average_progress": round(avg_progress, 1),
            "current_streak": current_streak
        }
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

