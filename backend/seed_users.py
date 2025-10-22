from app.database import SessionLocal
from app.models.user import User
from app.models.wish import Wish  # Import to avoid relationship errors
from app.core.security import get_password_hash

def seed_users():
    db = SessionLocal()
    
    # Check if users already exist
    existing_users = db.query(User).count()
    if existing_users > 5:
        print(f"Database already has {existing_users} users. Skipping seed.")
        db.close()
        return
    
    fake_users = [
        {"username": "john_doe", "email": "john@example.com", "password": "password123"},
        {"username": "jane_smith", "email": "jane@example.com", "password": "password123"},
        {"username": "bob_wilson", "email": "bob@example.com", "password": "password123"},
        {"username": "alice_johnson", "email": "alice@example.com", "password": "password123"},
        {"username": "mike_brown", "email": "mike@example.com", "password": "password123"},
        {"username": "sara_davis", "email": "sara@example.com", "password": "password123"},
        {"username": "tom_miller", "email": "tom@example.com", "password": "password123"},
        {"username": "emma_wilson", "email": "emma@example.com", "password": "password123"},
        {"username": "david_lee", "email": "david@example.com", "password": "password123"},
        {"username": "sophia_garcia", "email": "sophia@example.com", "password": "password123"},
    ]
    
    added_count = 0
    for user_data in fake_users:
        # Check if user already exists
        existing = db.query(User).filter(
            (User.email == user_data["email"]) | (User.username == user_data["username"])
        ).first()
        
        if not existing:
            user = User(
                username=user_data["username"],
                email=user_data["email"],
                hashed_password=get_password_hash(user_data["password"])
            )
            db.add(user)
            added_count += 1
            print(f"Added user: {user_data['username']}")
    
    db.commit()
    db.close()
    print(f"\nSuccessfully added {added_count} fake users!")
    print("All users can login with password: 'password123'")

if __name__ == "__main__":
    seed_users()

