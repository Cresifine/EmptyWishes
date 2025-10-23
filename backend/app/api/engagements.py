from fastapi import APIRouter, HTTPException, status, Depends, Header
from sqlalchemy.orm import Session
from sqlalchemy import func
from typing import Optional
from app.schemas.engagement import LikeCreate, CommentCreate, CommentUpdate, ViewCreate, EngagementStats
from app.database import get_db
from app.models.like import Like
from app.models.comment import Comment
from app.models.view import View
from app.models.user import User
from app.models.wish import Wish
from app.api.users import get_current_user_from_token
from app.api.notifications import create_notification

router = APIRouter()

@router.post("/likes", status_code=status.HTTP_201_CREATED)
def toggle_like(
    like: LikeCreate, 
    authorization: Optional[str] = Header(None),
    db: Session = Depends(get_db)
):
    # Get current user
    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(status_code=401, detail="Not authenticated")
    
    token = authorization.replace("Bearer ", "")
    try:
        user = get_current_user_from_token(token, db)
        user_id = user.id
    except:
        raise HTTPException(status_code=401, detail="Invalid token")
    # Check if already liked
    existing_like = db.query(Like).filter(
        Like.user_id == user_id,
        Like.wish_id == like.wish_id
    ).first()
    
    if existing_like:
        # Unlike
        db.delete(existing_like)
        db.commit()
        return {"message": "Unliked", "liked": False}
    else:
        # Like
        new_like = Like(user_id=user_id, wish_id=like.wish_id)
        db.add(new_like)
        db.commit()
        
        # Create notification for wish owner
        wish = db.query(Wish).filter(Wish.id == like.wish_id).first()
        if wish:
            create_notification(
                db=db,
                user_id=wish.user_id,
                notification_type="like",
                wish_id=wish.id,
                actor_id=user_id
            )
        
        return {"message": "Liked", "liked": True}

@router.post("/comments", status_code=status.HTTP_201_CREATED)
def create_comment(
    comment: CommentCreate, 
    authorization: Optional[str] = Header(None),
    db: Session = Depends(get_db)
):
    # Get current user
    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(status_code=401, detail="Not authenticated")
    
    token = authorization.replace("Bearer ", "")
    try:
        user = get_current_user_from_token(token, db)
        user_id = user.id
    except:
        raise HTTPException(status_code=401, detail="Invalid token")
    
    new_comment = Comment(
        user_id=user_id,
        wish_id=comment.wish_id,
        content=comment.content
    )
    db.add(new_comment)
    db.commit()
    db.refresh(new_comment)
    
    # Create notification for wish owner
    wish = db.query(Wish).filter(Wish.id == comment.wish_id).first()
    if wish:
        create_notification(
            db=db,
            user_id=wish.user_id,
            notification_type="comment",
            wish_id=wish.id,
            actor_id=user_id,
            content=comment.content
        )
    
    return new_comment

@router.get("/wishes/{wish_id}/stats")
def get_engagement_stats(wish_id: int, user_id: int = 1, db: Session = Depends(get_db)):
    likes_count = db.query(func.count(Like.id)).filter(Like.wish_id == wish_id).scalar()
    comments_count = db.query(func.count(Comment.id)).filter(Comment.wish_id == wish_id).scalar()
    views_count = db.query(func.count(View.id)).filter(View.wish_id == wish_id).scalar()
    
    is_liked = db.query(Like).filter(
        Like.user_id == user_id,
        Like.wish_id == wish_id
    ).first() is not None
    
    return {
        "wish_id": wish_id,
        "likes_count": likes_count or 0,
        "comments_count": comments_count or 0,
        "views_count": views_count or 0,
        "is_liked": is_liked
    }

@router.post("/views", status_code=status.HTTP_201_CREATED)
def record_view(view: ViewCreate, user_id: int = 1, db: Session = Depends(get_db)):
    new_view = View(user_id=user_id, wish_id=view.wish_id)
    db.add(new_view)
    db.commit()
    return {"message": "View recorded"}

@router.get("/wishes/{wish_id}/comments")
def get_comments(wish_id: int, db: Session = Depends(get_db)):
    """Get all comments for a wish"""
    comments = db.query(Comment).filter(Comment.wish_id == wish_id).order_by(Comment.created_at.desc()).all()
    
    result = []
    for comment in comments:
        user = db.query(User).filter(User.id == comment.user_id).first()
        result.append({
            "id": comment.id,
            "wish_id": comment.wish_id,
            "user_id": comment.user_id,
            "username": user.username if user else "Unknown",
            "content": comment.content,
            "created_at": comment.created_at.isoformat()
        })
    
    return result

