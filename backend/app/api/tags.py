from fastapi import APIRouter, HTTPException, status, Depends, Header
from sqlalchemy.orm import Session
from sqlalchemy import func, or_
from typing import List, Optional
from app.database import get_db
from app.models.tag import Tag
from app.schemas.tag import TagResponse, PopularTagResponse
from app.api.users import get_current_user_from_token

router = APIRouter()

@router.get("/popular", response_model=List[PopularTagResponse])
def get_popular_tags(
    limit: int = 20,
    db: Session = Depends(get_db)
):
    """Get popular tags sorted by usage count"""
    tags = db.query(Tag).order_by(Tag.usage_count.desc()).limit(limit).all()
    return tags

@router.get("/search", response_model=List[TagResponse])
def search_tags(
    q: str,
    limit: int = 10,
    db: Session = Depends(get_db)
):
    """Search tags by name (autocomplete)"""
    if len(q) < 2:
        return []
    
    tags = db.query(Tag).filter(
        Tag.name.ilike(f"%{q}%")
    ).order_by(Tag.usage_count.desc()).limit(limit).all()
    
    return tags

@router.get("/", response_model=List[TagResponse])
def get_all_tags(
    skip: int = 0,
    limit: int = 100,
    db: Session = Depends(get_db)
):
    """Get all tags"""
    tags = db.query(Tag).order_by(Tag.name).offset(skip).limit(limit).all()
    return tags

@router.get("/{tag_id}", response_model=TagResponse)
def get_tag(tag_id: int, db: Session = Depends(get_db)):
    """Get a specific tag by ID"""
    tag = db.query(Tag).filter(Tag.id == tag_id).first()
    if not tag:
        raise HTTPException(status_code=404, detail="Tag not found")
    return tag

def get_or_create_tag(db: Session, tag_name: str) -> Tag:
    """Get existing tag or create a new one"""
    # Normalize tag name: lowercase, strip whitespace
    normalized_name = tag_name.strip().lower()
    
    if not normalized_name:
        return None
    
    # Check if tag exists
    tag = db.query(Tag).filter(Tag.name == normalized_name).first()
    
    if not tag:
        # Create new tag
        tag = Tag(name=normalized_name, usage_count=0)
        db.add(tag)
        db.flush()
    
    return tag

