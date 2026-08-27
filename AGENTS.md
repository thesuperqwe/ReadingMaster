# Repository Guidelines

## Project Status

ReadingMaster（阅读王）is an AI English graded-reading product for elementary school children. The MVP is Web-first, designed for iPad Safari / Chrome; the Android APK is a later validation target. The repository is currently in Phase 1; [docs/DESIGN.md](docs/DESIGN.md) is the source of truth for scope, architecture, APIs, and the Phase 0–7 roadmap.

## Project Structure & Module Organization

Target layout once scaffolded:

```text
apps/
  mobile/    Flutter app (MVP targets Web first, Android later)
  backend/   FastAPI app
database/    Alembic migrations, seed data
docs/        PRD, API, DATABASE, DEVELOPMENT
scripts/     dev.sh, seed.sh
```

Separate API routers, service logic, ORM models, and Pydantic schemas; in Flutter, keep pages, models, and services separate.

## Build, Test, and Development Commands

After Phase 0:

- `docker compose up` — start PostgreSQL, Redis, and the FastAPI backend; verify with `GET /health`.
- `uvicorn app.main:app --reload` — run the backend; `pytest` — backend tests.
- `flutter run -d chrome` — run the MVP Web app in Chrome; `flutter build web` — produce the web build for iPad testing; `flutter test` — unit/widget tests.
- `alembic upgrade head` — apply migrations; run `python -m app.db.seed` from `apps/backend` to load sample content.

These commands do not exist yet; do not invent infrastructure.

## Coding Style & Naming Conventions

- Python: 4-space indentation; `snake_case` functions/variables, `PascalCase` classes; type hints, Pydantic validation, SQLAlchemy ORM.
- Flutter/Dart: 2-space indentation; `camelCase` variables/functions, `PascalCase` classes/files (`reader_page.dart` → `ReaderPage`), `lowercase_with_underscores` directories.
- All API routes use the `/api/v1` prefix; responses are JSON with a unified error format.
- Configure via environment variables (`.env.example`); never hardcode API keys — AI keys live only on the backend.

## Testing Guidelines

- Backend: pytest; cover core business logic and key APIs (auth, reading, quiz, vocabulary).
- Name tests by behavior: `test_register_creates_parent_user`, `login_page_test.dart`.
- Never delete or weaken failing tests to make the suite pass; fix the code instead.
- Run the full suite after any phase before reporting done.

## Commit & Pull Request Guidelines

No commit history exists yet; adopt these conventions:

- Use conventional commits: `feat(backend): add reading session API`, `fix(reader): handle empty pages`, `chore(deps): update Flutter SDK`.
- Keep commits focused on one logical change.
- Open a PR per feature or fix: description, a reference to the issue or design-doc section, and run/test instructions.
- Before merging, verify tests pass and no `TODO`s from the current phase remain.

## Agent-Specific Instructions

- Start every task by reading [docs/DESIGN.md](docs/DESIGN.md) and checking the project structure — never assume files exist.
- Work only on the current phase; when done, summarize changes and provide run/test instructions.
- Prioritize MVP scope; avoid speculative features the design doc does not require.
