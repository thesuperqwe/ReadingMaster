from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.api import auth, books, children, home, quiz, reading, vocabulary, words

app = FastAPI(title="ReadingMaster API", version="0.1.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)

api_prefix = "/api/v1"
app.include_router(auth.router, prefix=api_prefix)
app.include_router(children.router, prefix=api_prefix)
app.include_router(home.router, prefix=api_prefix)
app.include_router(books.router, prefix=api_prefix)
app.include_router(words.router, prefix=api_prefix)
app.include_router(reading.router, prefix=api_prefix)
app.include_router(quiz.router, prefix=api_prefix)
app.include_router(vocabulary.router, prefix=api_prefix)


@app.get("/health")
def health() -> dict[str, str]:
    return {"status": "ok"}
