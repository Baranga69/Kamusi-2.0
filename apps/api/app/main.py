from fastapi import FastAPI

from app.routers import admin, public

app = FastAPI(title="Kamusi API")

app.include_router(public.router)
app.include_router(admin.router)
