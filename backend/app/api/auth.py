from fastapi import APIRouter, HTTPException, status, Depends, Form
from sqlalchemy.orm import Session
from app.schemas.user import UserCreate, UserResponse, Token
from app.core.security import create_access_token, get_password_hash, verify_password
from app.database import get_db
from app.models.user import User
import logging

logger = logging.getLogger(__name__)
router = APIRouter()

@router.post("/register", response_model=UserResponse, status_code=status.HTTP_201_CREATED)
def register(user: UserCreate, db: Session = Depends(get_db)):
    logger.info(f"Registration attempt for email: {user.email}")
    
    # Check if user exists
    if db.query(User).filter(User.email == user.email).first():
        logger.warning(f"Email already registered: {user.email}")
        raise HTTPException(status_code=400, detail="Email already registered")
    if db.query(User).filter(User.username == user.username).first():
        logger.warning(f"Username already taken: {user.username}")
        raise HTTPException(status_code=400, detail="Username already taken")
    
    # Create new user
    db_user = User(
        email=user.email,
        username=user.username,
        hashed_password=get_password_hash(user.password)
    )
    db.add(db_user)
    db.commit()
    db.refresh(db_user)
    logger.info(f"User registered successfully: {user.email}")
    return db_user

@router.post("/login", response_model=Token)
def login(
    email: str = Form(...),
    password: str = Form(...),
    db: Session = Depends(get_db)
):
    logger.info(f"Login attempt for email: {email}")
    user = db.query(User).filter(User.email == email).first()
    if not user or not verify_password(password, user.hashed_password):
        logger.warning(f"Failed login attempt for email: {email}")
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect email or password"
        )
    
    access_token = create_access_token(data={"sub": user.email})
    logger.info(f"User logged in successfully: {email}")
    return {"access_token": access_token, "token_type": "bearer"}

