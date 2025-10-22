from fastapi import APIRouter, HTTPException, status, Depends, UploadFile, File, Form
from sqlalchemy.orm import Session
from typing import List, Optional
from app.schemas.progress_update import ProgressUpdateCreate, ProgressUpdateResponse
from app.database import get_db
from app.models.progress_update import ProgressUpdate
from app.models.wish import Wish
from app.models.attachment import Attachment
from app.api.users import get_current_user_from_credentials
from app.models.user import User
import os
import uuid
import mimetypes
from pathlib import Path

router = APIRouter()

# Create uploads directory if it doesn't exist
UPLOAD_DIR = Path("uploads")
UPLOAD_DIR.mkdir(exist_ok=True)

@router.post("/wishes/{wish_id}/progress", status_code=status.HTTP_201_CREATED)
async def create_progress_update(
    wish_id: int,
    content: str = Form(""),
    progress_value: Optional[int] = Form(None),
    files: List[UploadFile] = File([]),
    current_user: User = Depends(get_current_user_from_credentials),
    db: Session = Depends(get_db)
):
    """Create a new progress update for a wish with optional file attachments"""
    # Verify wish exists and belongs to user
    wish = db.query(Wish).filter(Wish.id == wish_id, Wish.user_id == current_user.id).first()
    if not wish:
        raise HTTPException(status_code=404, detail="Wish not found or doesn't belong to you")
    
    # Validate progress cannot decrease
    if progress_value is not None and progress_value < wish.progress:
        raise HTTPException(
            status_code=400, 
            detail=f"Cannot decrease progress below current value of {wish.progress}%"
        )
    
    # Auto-generate content if empty and progress provided
    if not content.strip():
        if progress_value is not None:
            if progress_value >= 100:
                content = "Goal completed! 🎉"
            else:
                content = f"Progress updated to {progress_value}%"
        elif files:
            content = "Added attachment(s)"
        else:
            raise HTTPException(status_code=400, detail="Content, progress value, or files must be provided")
    
    # Create progress update
    progress_update = ProgressUpdate(
        wish_id=wish_id,
        user_id=current_user.id,
        content=content,
        progress_value=progress_value
    )
    
    db.add(progress_update)
    db.flush()  # Get the ID for attachments
    
    # Handle file uploads
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
                progress_update_id=progress_update.id
            )
            db.add(attachment)
    
    # Update wish progress if provided
    if progress_value is not None:
        wish.progress = progress_value
        if progress_value >= 100:
            wish.is_completed = True
            wish.status = "completed"
    
    db.commit()
    db.refresh(progress_update)
    
    # Return response with attachments
    return {
        "id": progress_update.id,
        "wish_id": progress_update.wish_id,
        "user_id": progress_update.user_id,
        "content": progress_update.content,
        "progress_value": progress_update.progress_value,
        "created_at": progress_update.created_at.isoformat(),
        "attachments": [
            {
                "id": att.id,
                "file_name": att.file_name,
                "file_path": att.file_path,
                "file_type": att.file_type,
                "file_size": att.file_size
            }
            for att in progress_update.attachments
        ]
    }

@router.get("/wishes/{wish_id}/progress")
def get_progress_updates(
    wish_id: int,
    db: Session = Depends(get_db)
):
    """Get all progress updates for a wish"""
    # Verify wish exists
    wish = db.query(Wish).filter(Wish.id == wish_id).first()
    if not wish:
        raise HTTPException(status_code=404, detail="Wish not found")
    
    updates = db.query(ProgressUpdate).filter(
        ProgressUpdate.wish_id == wish_id
    ).order_by(ProgressUpdate.created_at.desc()).all()
    
    return [
        {
            "id": update.id,
            "wish_id": update.wish_id,
            "user_id": update.user_id,
            "content": update.content,
            "progress_value": update.progress_value,
            "created_at": update.created_at.isoformat(),
            "image_url": update.image_url,  # Keep for backwards compatibility
            "attachments": [
                {
                    "id": att.id,
                    "file_name": att.file_name,
                    "file_path": att.file_path,
                    "file_type": att.file_type,
                    "file_size": att.file_size
                }
                for att in update.attachments
            ]
        }
        for update in updates
    ]

