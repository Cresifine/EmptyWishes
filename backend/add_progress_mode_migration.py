from app.database import engine
from sqlalchemy import text

def add_progress_mode_column():
    """Add progress_mode column to wishes table"""
    with engine.connect() as conn:
        try:
            # Check if column already exists
            result = conn.execute(text("PRAGMA table_info(wishes)"))
            columns = [row[1] for row in result]
            
            if 'progress_mode' not in columns:
                # Add the column with default value
                conn.execute(text(
                    "ALTER TABLE wishes ADD COLUMN progress_mode VARCHAR DEFAULT 'manual'"
                ))
                conn.commit()
                print("✅ Added progress_mode column to wishes table")
            else:
                print("⚠️  Column progress_mode already exists")
        except Exception as e:
            print(f"❌ Error: {e}")

if __name__ == "__main__":
    add_progress_mode_column()
