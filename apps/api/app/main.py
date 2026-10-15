from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

import logging

from app.core.config import settings, warn_on_insecure_defaults
from app.routers import admin, admin_review, auth, learn, public

app = FastAPI(title="Kamusi API")

logger = logging.getLogger("kamusi")
for problem in warn_on_insecure_defaults():
    # Loud but not fatal: refusing to boot would make a first local run
    # confusing, and these are exactly the settings a deploy must override.
    logger.warning("INSECURE DEFAULT: %s", problem)

if settings.cors_origins:
    app.add_middleware(
        CORSMiddleware,
        allow_origins=settings.cors_origins,
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )

app.include_router(public.router)
app.include_router(learn.router)
app.include_router(auth.router)
app.include_router(auth.users_router)
app.include_router(admin.router)
app.include_router(admin_review.router)
