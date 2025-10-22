from fastapi import APIRouter, HTTPException, status, Depends, Header, UploadFile, File, Form
from sqlalchemy.orm import Session
from typing import List, Optional
from datetime import datetime
from app.schemas.wish import WishCreate, WishUpdate, WishResponse
from app.database import get_db
from app.models.wish import Wish
from app.models.attachment import Attachment
from app.api.users import get_current_user_from_token
import shutil
import mimetypes
from pathlib import Path
import uuid
import os

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
        user_id=user_id,
        status="current"
    )
    db.add(db_wish)
    db.flush()  # Get the ID for attachments
    
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
    
    # Return with attachments
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

@router.get("/{wish_id}", response_model=WishResponse)
def get_wish(wish_id: int, db: Session = Depends(get_db)):
    wish = db.query(Wish).filter(Wish.id == wish_id).first()
    if not wish:
        raise HTTPException(status_code=404, detail="Wish not found")
    return wish

@router.patch("/{wish_id}", response_model=WishResponse)
def update_wish(wish_id: int, wish_update: WishUpdate, db: Session = Depends(get_db)):
    db_wish = db.query(Wish).filter(Wish.id == wish_id).first()
    if not db_wish:
        raise HTTPException(status_code=404, detail="Wish not found")
    
    update_data = wish_update.model_dump(exclude_unset=True)
    for field, value in update_data.items():
        setattr(db_wish, field, value)
    
    db.commit()
    db.refresh(db_wish)
    return db_wish

@router.delete("/{wish_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_wish(wish_id: int, db: Session = Depends(get_db)):
    wish = db.query(Wish).filter(Wish.id == wish_id).first()
    if not wish:
        raise HTTPException(status_code=404, detail="Wish not found")
    
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

