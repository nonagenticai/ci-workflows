"""A minimal service: one health endpoint, which is all the smoke test needs."""

from fastapi import FastAPI

app = FastAPI(title="ci-workflows fixture")


@app.get("/health")
def health() -> dict[str, str]:
    return {"status": "ok"}
