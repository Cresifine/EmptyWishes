from app.database import engine, Base
from app.models.user import User
from app.models.wish import Wish
from app.models.like import Like
from app.models.comment import Comment
from app.models.view import View
from app.models.engagement import Engagement
from app.models.user_statistics import UserStatistics
from app.models.progress_update import ProgressUpdate
from app.models.attachment import Attachment

def init_db():
    Base.metadata.create_all(bind=engine)
    print("Database tables created successfully!")
    print("Created tables: users, wishes, likes, comments, views, engagements, user_statistics, progress_updates, attachments")

if __name__ == "__main__":
    init_db()

