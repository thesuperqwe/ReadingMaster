import os

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles

from app.api import ai, asr, auth, books, children, home, quiz, reading, stats, tts, vocabulary, words

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
app.include_router(stats.router, prefix=api_prefix)
app.include_router(tts.router, prefix=api_prefix)
app.include_router(asr.router, prefix=api_prefix)
app.include_router(ai.router, prefix=api_prefix)


@app.get("/health")
def health() -> dict[str, str]:
    return {"status": "ok"}


# Optional: also serve the Flutter Web build so a single tunnel/origin can host
# both the SPA and the API. We mount it last so the /api/v1 routes above always
# win. Set WEB_DIST_DIR to the directory containing index.html.
web_dist = os.environ.get("WEB_DIST_DIR", "/app/web")
if os.path.isdir(web_dist) and os.path.exists(os.path.join(web_dist, "index.html")):
    app.mount("/", StaticFiles(directory=web_dist, html=True), name="web")
