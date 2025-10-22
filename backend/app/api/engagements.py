from fastapi import APIRouter, HTTPException, status, Depends
from sqlalchemy.orm import Session
from sqlalchemy import func
from app.schemas.engagement import LikeCreate, CommentCreate, CommentUpdate, ViewCreate, EngagementStats
from app.database import get_db
from app.models.like import Like
from app.models.comment import Comment
from app.models.view import View

router = APIRouter()

@router.post("/likes", status_code=status.HTTP_201_CREATED)
def toggle_like(like: LikeCreate, user_id: int = 1, db: Session = Depends(get_db)):
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
        return {"message": "Liked", "liked": True}

@router.post("/comments", status_code=status.HTTP_201_CREATED)
def create_comment(comment: CommentCreate, user_id: int = 1, db: Session = Depends(get_db)):
    new_comment = Comment(
        user_id=user_id,
        wish_id=comment.wish_id,
        content=comment.content
    )
    db.add(new_comment)
    db.commit()
    db.refresh(new_comment)
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

