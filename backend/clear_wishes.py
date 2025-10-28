"""
Clear all wishes (goals) from the database
"""
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from app.database import Base
from app.models.wish import Wish
from app.models.milestone import Milestone

# Database URL (must match config.py)
DATABASE_URL = "sqlite:///./wishes.db"

# Create engine
engine = create_engine(DATABASE_URL, connect_args={"check_same_thread": False})
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

def clear_all_wishes():
    """Delete all wishes and their associated milestones"""
    db = SessionLocal()
    try:
        # Try to delete milestones first (if table exists)
        try:
            milestones_deleted = db.query(Milestone).delete()
            print(f"Deleted {milestones_deleted} milestones")
        except Exception as e:
            print(f"Note: Milestones table doesn't exist or is empty: {e}")
            db.rollback()
        
        # Delete all wishes
        wishes_deleted = db.query(Wish).delete()
        print(f"Deleted {wishes_deleted} wishes")
        
        db.commit()
        print("✅ Successfully cleared all wishes from the database!")
        
    except Exception as e:
        db.rollback()
        print(f"❌ Error clearing database: {e}")
    finally:
        db.close()

if __name__ == "__main__":
    print("⚠️  This will delete ALL wishes and milestones from the database!")
    confirm = input("Are you sure you want to continue? (yes/no): ")
    if confirm.lower() == 'yes':
        clear_all_wishes()
    else:
        print("Operation cancelled.")

