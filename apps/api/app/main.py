from fastapi import FastAPI

app = FastAPI(title="Kamusi API")


@app.get("/health")
def health() -> dict[str, str]:
    return {"status": "ok"}
