from fastapi import APIRouter, HTTPException, status, Depends, Header, UploadFile, File, Form
from sqlalchemy.orm import Session
from sqlalchemy import func, or_
from typing import List, Optional
from datetime import datetime
from app.schemas.wish import WishCreate, WishUpdate, WishResponse
from app.database import get_db
from app.models.wish import Wish
from app.models.attachment import Attachment
from app.models.tag import Tag
from app.models.user import User
from app.models.like import Like
from app.models.comment import Comment
from app.models.view import View
from app.api.users import get_current_user_from_token
from app.api.tags import get_or_create_tag
import shutil
import mimetypes
from pathlib import Path
import uuid
import os
import json

router = APIRouter()

UPLOAD_DIR = Path("uploads")
UPLOAD_DIR.mkdir(exist_ok=True)

def auto_update_wish_status(wish: Wish):
    """Automatically update wish status based on progress and deadline"""
    if wish.progress >= 100:
        wish.status = "completed"
        wish.is_completed = True
    elif wish.target_date and wish.target_date < datetime.utcnow() and wish.progress < 100:
        wish.status = "missed"
    return wish

@router.post("", status_code=status.HTTP_201_CREATED)
async def create_wish(
    title: str = Form(...),
    description: Optional[str] = Form(None),
    target_date: Optional[str] = Form(None),
    consequence: Optional[str] = Form(None),
    visibility: str = Form("public"),  # public, followers, friends, private
    tags: Optional[str] = Form(None),  # JSON array of tag names
    cover_image: Optional[UploadFile] = File(None),
    files: List[UploadFile] = File([]),
    authorization: Optional[str] = Header(None),
    db: Session = Depends(get_db)
):
    # Try to get user from token, default to user_id=1 if offline/no token
    user_id = 1
    if authorization and authorization.startswith("Bearer "):
        token = authorization.replace("Bearer ", "")
        try:
            user = get_current_user_from_token(token, db)
            user_id = user.id
        except:
            pass  # Use default user_id if token invalid
    
    # Handle cover image upload
    cover_image_url = None
    if cover_image:
        unique_filename = f"{uuid.uuid4()}_{cover_image.filename}"
        file_path = UPLOAD_DIR / unique_filename
        with file_path.open("wb") as buffer:
            shutil.copyfileobj(cover_image.file, buffer)
        cover_image_url = f"/uploads/{unique_filename}"
    
    # Parse target_date
    parsed_target_date = None
    if target_date:
        try:
            parsed_target_date = datetime.fromisoformat(target_date.replace('Z', '+00:00'))
        except:
            pass
    
    db_wish = Wish(
        title=title,
        description=description or "",
        target_date=parsed_target_date,
        consequence=consequence,
        cover_image=cover_image_url,
        visibility=visibility,
        user_id=user_id,
        status="current"
    )
    db.add(db_wish)
    db.flush()  # Get the ID for attachments and tags
    
    # Handle tags
    if tags:
        try:
            tag_names = json.loads(tags)
            for tag_name in tag_names:
                tag = get_or_create_tag(db, tag_name)
                if tag:
                    db_wish.tags.append(tag)
                    tag.usage_count += 1
        except json.JSONDecodeError:
            print(f"[create_wish] Failed to parse tags JSON: {tags}")
    
    # Handle file attachments
    for file in files:
        if file and file.filename:
            # Generate unique filename
            file_extension = os.path.splitext(file.filename)[1]
            unique_filename = f"{uuid.uuid4()}{file_extension}"
            file_path = UPLOAD_DIR / unique_filename
            
            # Save file
            with open(file_path, "wb") as buffer:
                content_bytes = await file.read()
                buffer.write(content_bytes)
            
            # Guess MIME type
            mime_type = mimetypes.guess_type(file.filename)[0] or "application/octet-stream"
            
            # Create attachment record
            attachment = Attachment(
                file_name=file.filename,
                file_path=f"/uploads/{unique_filename}",
                file_type=mime_type,
                file_size=len(content_bytes),
                wish_id=db_wish.id
            )
            db.add(attachment)
    
    db.commit()
    db.refresh(db_wish)
    
    # Return with attachments and tags
    return {
        "id": db_wish.id,
        "title": db_wish.title,
        "description": db_wish.description,
        "progress": db_wish.progress,
        "is_completed": db_wish.is_completed,
        "status": db_wish.status,
        "created_at": db_wish.created_at.isoformat(),
        "target_date": db_wish.target_date.isoformat() if db_wish.target_date else None,
        "consequence": db_wish.consequence,
        "cover_image": db_wish.cover_image,
        "user_id": db_wish.user_id,
        "tags": [{"id": tag.id, "name": tag.name} for tag in db_wish.tags],
        "attachments": [
            {
                "id": att.id,
                "file_name": att.file_name,
                "file_path": att.file_path,
                "file_type": att.file_type,
                "file_size": att.file_size
            }
            for att in db_wish.attachments
        ]
    }

@router.get("", response_model=List[WishResponse])
def get_wishes(
    status_filter: Optional[str] = None,
    authorization: Optional[str] = Header(None),
    db: Session = Depends(get_db)
):
    # Try to get user from token, default to user_id=1 if offline/no token
    user_id = 1
    if authorization and authorization.startswith("Bearer "):
        token = authorization.replace("Bearer ", "")
        try:
            user = get_current_user_from_token(token, db)
            user_id = user.id
        except:
            pass
    
    query = db.query(Wish).filter(Wish.user_id == user_id)
    
    # Auto-update statuses before querying
    all_wishes = query.all()
    for wish in all_wishes:
        auto_update_wish_status(wish)
    db.commit()
    
    # Apply filter if provided
    if status_filter:
        query = query.filter(Wish.status == status_filter)
        wishes = query.all()
    else:
        wishes = all_wishes
    
    return wishes

@router.get("/public/feed")
def get_public_feed(
    filter_type: Optional[str] = None,
    tag: Optional[str] = None,  # Filter by tag name
    authorization: Optional[str] = Header(None),
    db: Session = Depends(get_db)
):
    """Get public feed of wishes with engagement stats, sorted by engagement"""
    # Get current user if authenticated
    current_user_id = None
    if authorization and authorization.startswith("Bearer "):
        token = authorization.replace("Bearer ", "")
        try:
            user = get_current_user_from_token(token, db)
            current_user_id = user.id
        except:
            pass
    
    # Get wishes based on visibility and user relationship
    from app.models.follow import Follow
    
    # Start with wishes that are not archived or missed
    query = db.query(Wish).filter(
        Wish.status.in_(["current", "completed"])
    )
    
    if current_user_id:
        # Get following relationships
        following_ids = db.query(Follow.following_id).filter(
            Follow.follower_id == current_user_id
        ).all()
        following_ids = [fid[0] for fid in following_ids]
        
        # Get followers (for friends check)
        followers_ids = db.query(Follow.follower_id).filter(
            Follow.following_id == current_user_id
        ).all()
        followers_ids = [fid[0] for fid in followers_ids]
        
        # Friends are mutual follows
        friends_ids = list(set(following_ids) & set(followers_ids))
        
        # Build visibility filter
        # Show: public posts, own posts, posts from followed users if visibility allows
        visibility_conditions = [
            Wish.visibility == "public",  # Public posts
            Wish.user_id == current_user_id,  # Own posts
        ]
        
        # Posts visible to followers (if user is following the poster)
        if following_ids:
            visibility_conditions.append(
                (Wish.visibility == "followers") & (Wish.user_id.in_(following_ids))
            )
        
        # Posts visible to friends only (if mutual follow)
        if friends_ids:
            visibility_conditions.append(
                (Wish.visibility == "friends") & (Wish.user_id.in_(friends_ids))
            )
        
        query = query.filter(or_(*visibility_conditions))
        
        # Filter by following if specified
        if filter_type == "Following":
            if following_ids:
                query = query.filter(Wish.user_id.in_(following_ids))
            else:
                return []
    else:
        # Not logged in - only show public posts
        query = query.filter(Wish.visibility == "public")
    
    # Filter by tag if specified
    if tag:
        query = query.join(Wish.tags).filter(Tag.name == tag.lower())
    
    wishes = query.all()
    
    # Build feed items with engagement stats
    feed_items = []
    for wish in wishes:
        # Get engagement stats
        likes_count = db.query(func.count(Like.id)).filter(Like.wish_id == wish.id).scalar() or 0
        comments_count = db.query(func.count(Comment.id)).filter(Comment.wish_id == wish.id).scalar() or 0
        views_count = db.query(func.count(View.id)).filter(View.wish_id == wish.id).scalar() or 0
        
        # Check if current user liked this
        is_liked = False
        if current_user_id:
            is_liked = db.query(Like).filter(
                Like.user_id == current_user_id,
                Like.wish_id == wish.id
            ).first() is not None
        
        # Get wish owner info
        owner = db.query(User).filter(User.id == wish.user_id).first()
        
        # Calculate engagement score (formula: likes * 3 + comments * 5 + views * 0.1)
        engagement_score = (likes_count * 3) + (comments_count * 5) + (views_count * 0.1)
        
        feed_items.append({
            "wish": {
                "id": wish.id,
                "title": wish.title,
                "description": wish.description,
                "progress": wish.progress,
                "is_completed": wish.is_completed,
                "status": wish.status,
                "created_at": wish.created_at.isoformat(),
                "target_date": wish.target_date.isoformat() if wish.target_date else None,
                "cover_image": wish.cover_image,
                "consequence": wish.consequence,
                "tags": [{"id": tag.id, "name": tag.name} for tag in wish.tags],
                "attachments": [
                    {
                        "id": att.id,
                        "file_name": att.file_name,
                        "file_path": att.file_path,
                        "file_type": att.file_type,
                        "file_size": att.file_size
                    }
                    for att in wish.attachments
                ],
            },
            "user": {
                "id": owner.id,
                "username": owner.username,
                "email": owner.email,
            },
            "engagement": {
                "likes_count": likes_count,
                "comments_count": comments_count,
                "views_count": views_count,
                "is_liked": is_liked,
                "engagement_score": engagement_score,
            }
        })
    
    # Sort by engagement score (highest first) or by creation date
    if filter_type == "Popular":
        feed_items.sort(key=lambda x: x["engagement"]["engagement_score"], reverse=True)
    elif filter_type == "Recent":
        feed_items.sort(key=lambda x: x["wish"]["created_at"], reverse=True)
    else:  # All or default
        # Sort by engagement score for default view
        feed_items.sort(key=lambda x: x["engagement"]["engagement_score"], reverse=True)
    
    return feed_items

@router.get("/{wish_id}", response_model=WishResponse)
def get_wish(wish_id: int, db: Session = Depends(get_db)):
    wish = db.query(Wish).filter(Wish.id == wish_id).first()
    if not wish:
        raise HTTPException(status_code=404, detail="Wish not found")
    return wish

@router.patch("/{wish_id}", response_model=WishResponse)
def update_wish(
    wish_id: int, 
    wish_update: WishUpdate, 
    authorization: Optional[str] = Header(None),
    db: Session = Depends(get_db)
):
    # Get current user
    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(status_code=401, detail="Not authenticated")
    
    token = authorization.replace("Bearer ", "")
    try:
        user = get_current_user_from_token(token, db)
    except:
        raise HTTPException(status_code=401, detail="Invalid token")
    
    # Get wish and verify ownership
    db_wish = db.query(Wish).filter(Wish.id == wish_id, Wish.user_id == user.id).first()
    if not db_wish:
        raise HTTPException(status_code=404, detail="Wish not found or doesn't belong to you")
    
    update_data = wish_update.model_dump(exclude_unset=True)
    for field, value in update_data.items():
        setattr(db_wish, field, value)
    
    db.commit()
    db.refresh(db_wish)
    return db_wish

@router.delete("/{wish_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_wish(
    wish_id: int, 
    authorization: Optional[str] = Header(None),
    db: Session = Depends(get_db)
):
    # Get current user
    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(status_code=401, detail="Not authenticated")
    
    token = authorization.replace("Bearer ", "")
    try:
        user = get_current_user_from_token(token, db)
    except:
        raise HTTPException(status_code=401, detail="Invalid token")
    
    # Get wish and verify ownership
    wish = db.query(Wish).filter(Wish.id == wish_id, Wish.user_id == user.id).first()
    if not wish:
        raise HTTPException(status_code=404, detail="Wish not found or doesn't belong to you")
    
    db.delete(wish)
    db.commit()
    return None

@router.post("/{wish_id}/mark-failed", response_model=WishResponse)
def mark_wish_as_failed(
    wish_id: int,
    authorization: Optional[str] = Header(None),
    db: Session = Depends(get_db)
):
    """Mark a wish as failed"""
    # Get current user
    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(status_code=401, detail="Not authenticated")
    
    token = authorization.replace("Bearer ", "")
    try:
        user = get_current_user_from_token(token, db)
    except:
        raise HTTPException(status_code=401, detail="Invalid token")
    
    # Get wish
    wish = db.query(Wish).filter(Wish.id == wish_id, Wish.user_id == user.id).first()
    if not wish:
        raise HTTPException(status_code=404, detail="Wish not found or doesn't belong to you")
    
    # Update status to failed
    wish.status = "failed"
    db.commit()
    db.refresh(wish)
    return wish

