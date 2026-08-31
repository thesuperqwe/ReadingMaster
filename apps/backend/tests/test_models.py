from app import models  # noqa: F401
from app.db.base import Base


def test_core_tables_are_registered():
    table_names = set(Base.metadata.tables)

    assert {
        "users",
        "children",
        "books",
        "book_pages",
        "chapters",
        "words",
        "book_words",
        "reading_sessions",
        "reading_events",
        "user_words",
        "quiz_questions",
        "quiz_options",
        "quiz_attempts",
    } <= table_names


def test_user_words_tracks_learning_metrics():
    columns = set(Base.metadata.tables["user_words"].columns.keys())

    assert {
        "child_id",
        "word_id",
        "encounter_count",
        "click_count",
        "audio_count",
        "correct_count",
        "wrong_count",
        "mastery_score",
    } <= columns


def test_reading_events_support_core_interactions():
    columns = set(Base.metadata.tables["reading_events"].columns.keys())

    assert {
        "session_id",
        "child_id",
        "book_id",
        "page_no",
        "event_type",
        "word_id",
    } <= columns
