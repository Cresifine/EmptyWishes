from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from app.api import auth, wishes, users, engagements, progress_updates, notifications, tags, follows
import logging
import time
from pathlib import Path

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

app = FastAPI(
    title="EmptyWishes API",
    description="API for managing wishes and challenges",
    version="1.0.0"
)

# Add request logging middleware
@app.middleware("http")
async def log_requests(request: Request, call_next):
    start_time = time.time()
    logger.info(f"Request: {request.method} {request.url.path}")
    
    try:
        response = await call_next(request)
        process_time = time.time() - start_time
        logger.info(f"Response: {request.method} {request.url.path} - Status: {response.status_code} - Time: {process_time:.2f}s")
        return response
    except Exception as e:
        process_time = time.time() - start_time
        logger.error(f"Error: {request.method} {request.url.path} - {str(e)} - Time: {process_time:.2f}s")
        raise

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(auth.router, prefix="/api/auth", tags=["auth"])
app.include_router(users.router, prefix="/api/users", tags=["users"])
app.include_router(wishes.router, prefix="/api/wishes", tags=["wishes"])
app.include_router(engagements.router, prefix="/api/engagements", tags=["engagements"])
app.include_router(progress_updates.router, prefix="/api", tags=["progress_updates"])
app.include_router(notifications.router, prefix="/api/notifications", tags=["notifications"])
app.include_router(tags.router, prefix="/api/tags", tags=["tags"])
app.include_router(follows.router, prefix="/api/users", tags=["follows"])

# Mount uploads directory for serving uploaded images
UPLOAD_DIR = Path("uploads")
UPLOAD_DIR.mkdir(exist_ok=True)
app.mount("/uploads", StaticFiles(directory="uploads"), name="uploads")

@app.get("/")
def root():
    return {"message": "EmptyWishes API is running", "status": "ok"}

@app.get("/health")
def health_check():
    return {"status": "healthy", "message": "Backend is reachable"}

