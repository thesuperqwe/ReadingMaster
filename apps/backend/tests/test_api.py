import asyncio
import base64


def _register(client, email="parent@example.com"):
    response = client.post(
        "/api/v1/auth/register",
        json={"email": email, "password": "secret123"},
    )
    assert response.status_code == 201, response.text
    return response.json()


def _create_child(client, token, name="小明", level="LEVEL_2"):
    response = client.post(
        "/api/v1/children",
        headers={"Authorization": f"Bearer {token}"},
        json={"name": name, "grade": 3, "reading_level": level},
    )
    assert response.status_code == 201, response.text
    return response.json()


def test_auth_and_children_flow(client):
    registered = _register(client)
    token = registered["access_token"]
    child = _create_child(client, token)

    children_response = client.get(
        "/api/v1/children", headers={"Authorization": f"Bearer {token}"}
    )
    assert children_response.status_code == 200
    assert [item["id"] for item in children_response.json()] == [child["id"]]


def test_books_words_and_home(client, seed_content):
    registered = _register(client)
    token = registered["access_token"]
    child = _create_child(client, token)
    content = asyncio.run(seed_content())

    books_response = client.get(
        "/api/v1/books", headers={"Authorization": f"Bearer {token}"}
    )
    assert books_response.status_code == 200
    assert books_response.json()[0]["title"] == "The Little Dog"

    detail_response = client.get(
        f"/api/v1/books/{content['book_id']}",
        headers={"Authorization": f"Bearer {token}"},
    )
    assert detail_response.status_code == 200
    assert len(detail_response.json()["chapters"]) == 1

    chapter_response = client.get(
        f"/api/v1/books/{content['book_id']}/chapters/0",
        headers={"Authorization": f"Bearer {token}"},
    )
    assert chapter_response.status_code == 200
    assert len(chapter_response.json()["segments"]) == 3

    content_response = client.get(
        f"/api/v1/books/{content['book_id']}/content",
        headers={"Authorization": f"Bearer {token}"},
    )
    assert content_response.status_code == 200
    assert len(content_response.json()) == 3

    word_response = client.get(
        "/api/v1/words/cute", headers={"Authorization": f"Bearer {token}"}
    )
    assert word_response.status_code == 200
    assert word_response.json()["word"] == "cute"

    home_response = client.get(
        f"/api/v1/home?child_id={child['id']}",
        headers={"Authorization": f"Bearer {token}"},
    )
    assert home_response.status_code == 200
    assert home_response.json()["child"]["name"] == "小明"
    assert home_response.json()["recommended_book"]["id"] == content["book_id"]


def test_reading_flow_updates_vocabulary(client, seed_content):
    registered = _register(client)
    token = registered["access_token"]
    child = _create_child(client, token)
    content = asyncio.run(seed_content())

    session_response = client.post(
        "/api/v1/reading/sessions",
        headers={"Authorization": f"Bearer {token}"},
        json={"child_id": child["id"], "book_id": content["book_id"]},
    )
    assert session_response.status_code == 201, session_response.text
    session_id = session_response.json()["id"]

    event_response = client.post(
        "/api/v1/reading/events",
        headers={"Authorization": f"Bearer {token}"},
        json={"session_id": session_id, "page_no": 2, "event_type": "WORD_CLICK", "word": "cute"},
    )
    assert event_response.status_code == 201, event_response.text
    assert event_response.json()["word"] == "cute"

    finish_response = client.post(
        f"/api/v1/reading/sessions/{session_id}/finish",
        headers={"Authorization": f"Bearer {token}"},
        json={"duration_seconds": 120, "progress": 1.0, "completed": True},
    )
    assert finish_response.status_code == 200, finish_response.text
    assert finish_response.json()["completed"] is True

    vocabulary_response = client.get(
        f"/api/v1/children/{child['id']}/words",
        headers={"Authorization": f"Bearer {token}"},
    )
    assert vocabulary_response.status_code == 200
    words = vocabulary_response.json()
    assert len(words) == 1
    assert words[0]["word"]["word"] == "cute"
    assert words[0]["click_count"] == 1


def test_quiz_attempt_marks_correct_answer(client, seed_content):
    registered = _register(client)
    token = registered["access_token"]
    child = _create_child(client, token)
    content = asyncio.run(seed_content())

    quiz_response = client.get(
        f"/api/v1/books/{content['book_id']}/quiz",
        headers={"Authorization": f"Bearer {token}"},
    )
    assert quiz_response.status_code == 200
    question = quiz_response.json()[0]
    assert question["question"] == "What does Tom have?"

    attempt_response = client.post(
        "/api/v1/quiz/attempt",
        headers={"Authorization": f"Bearer {token}"},
        json={
            "child_id": child["id"],
            "question_id": question["id"],
            "selected_option": "A",
        },
    )
    assert attempt_response.status_code == 201, attempt_response.text
    assert attempt_response.json()["is_correct"] is True
    assert attempt_response.json()["correct_option"] == "A"


def test_books_require_authentication(client):
    response = client.get("/api/v1/books")
    assert response.status_code == 401


def test_unknown_word_returns_placeholder(client):
    registered = _register(client)
    token = registered["access_token"]

    response = client.get(
        "/api/v1/words/banana",
        headers={"Authorization": f"Bearer {token}"},
    )
    assert response.status_code == 200
    assert response.json()["word"] == "banana"
    assert response.json()["meaning_zh"] is None


def test_create_book_with_quiz(client):
    registered = _register(client)
    token = registered["access_token"]

    create_response = client.post(
        "/api/v1/books",
        headers={"Authorization": f"Bearer {token}"},
        json={
            "title": "A New Story",
            "level": "LEVEL_2",
            "content": "This is page one.\n\nThis is page two.",
            "questions": [
                {
                    "question": "What is the title?",
                    "correct_option": "A",
                    "options": [
                        {"option_key": "A", "content": "A New Story"},
                        {"option_key": "B", "content": "A Cat"},
                    ],
                }
            ],
        },
    )
    assert create_response.status_code == 201, create_response.text
    book_id = create_response.json()["id"]

    books_response = client.get(
        "/api/v1/books", headers={"Authorization": f"Bearer {token}"}
    )
    assert any(book["title"] == "A New Story" for book in books_response.json())

    quiz_response = client.get(
        f"/api/v1/books/{book_id}/quiz",
        headers={"Authorization": f"Bearer {token}"},
    )
    assert quiz_response.status_code == 200
    assert quiz_response.json()[0]["question"] == "What is the title?"


def test_full_reading_loop_updates_learning_data(client, seed_content):
    registered = _register(client)
    token = registered["access_token"]
    child = _create_child(client, token)
    content = asyncio.run(seed_content())

    session_response = client.post(
        "/api/v1/reading/sessions",
        headers={"Authorization": f"Bearer {token}"},
        json={"child_id": child["id"], "book_id": content["book_id"]},
    )
    assert session_response.status_code == 201
    session_id = session_response.json()["id"]

    for event in (
        {"page_no": 1, "event_type": "PAGE_VIEW", "word": None},
        {"page_no": 2, "event_type": "WORD_CLICK", "word": "cute"},
        {"page_no": 2, "event_type": "WORD_AUDIO", "word": "cute"},
        {"page_no": 2, "event_type": "WORD_MEANING", "word": "cute"},
    ):
        response = client.post(
            "/api/v1/reading/events",
            headers={"Authorization": f"Bearer {token}"},
            json={
                "session_id": session_id,
                "event_type": event["event_type"],
                "page_no": event["page_no"],
                **({"word": event["word"]} if event["word"] else {}),
            },
        )
        assert response.status_code == 201, response.text

    finish_response = client.post(
        f"/api/v1/reading/sessions/{session_id}/finish",
        headers={"Authorization": f"Bearer {token}"},
        json={"duration_seconds": 120, "progress": 1.0, "completed": True},
    )
    assert finish_response.status_code == 200
    assert finish_response.json()["completed"] is True

    quiz_response = client.get(
        f"/api/v1/books/{content['book_id']}/quiz",
        headers={"Authorization": f"Bearer {token}"},
    )
    question_id = quiz_response.json()[0]["id"]

    attempt_response = client.post(
        "/api/v1/quiz/attempt",
        headers={"Authorization": f"Bearer {token}"},
        json={"child_id": child["id"], "question_id": question_id, "selected_option": "A"},
    )
    assert attempt_response.status_code == 201
    assert attempt_response.json()["is_correct"] is True

    vocabulary_response = client.get(
        f"/api/v1/children/{child['id']}/words",
        headers={"Authorization": f"Bearer {token}"},
    )
    cute = next(
        item for item in vocabulary_response.json() if item["word"]["word"] == "cute"
    )
    assert cute["click_count"] == 1
    assert cute["audio_count"] == 1
    assert cute["encounter_count"] == 3
    assert cute["correct_count"] == 1
    assert cute["wrong_count"] == 0
    assert cute["mastery_score"] == 1.0


def test_ai_explain_word_uses_mock_provider(client):
    registered = _register(client)
    token = registered["access_token"]

    response = client.post(
        "/api/v1/ai/explain-word",
        headers={"Authorization": f"Bearer {token}"},
        json={"word": "cute", "context": "The dog is very cute."},
    )
    assert response.status_code == 200, response.text
    assert response.json()["meaning_zh"] == "可爱的"


def test_ai_generate_quiz_uses_mock_provider(client, seed_content):
    registered = _register(client)
    token = registered["access_token"]
    content = asyncio.run(seed_content())

    response = client.post(
        "/api/v1/ai/generate-quiz",
        headers={"Authorization": f"Bearer {token}"},
        json={"book_id": content["book_id"]},
    )
    assert response.status_code == 200, response.text
    assert len(response.json()["questions"]) == 3


def test_home_recommendation_prefers_reading_level(client, seed_content):
    registered = _register(client)
    token = registered["access_token"]
    child = _create_child(client, token, level="LEVEL_2")
    content = asyncio.run(seed_content())

    create_response = client.post(
        "/api/v1/books",
        headers={"Authorization": f"Bearer {token}"},
        json={"title": "Harder Story", "level": "LEVEL_3", "content": "This is a harder page."},
    )
    assert create_response.status_code == 201

    home_response = client.get(
        f"/api/v1/home?child_id={child['id']}",
        headers={"Authorization": f"Bearer {token}"},
    )
    assert home_response.status_code == 200
    assert home_response.json()["recommended_book"]["id"] == content["book_id"]


def test_review_schedules_srs(client, seed_content):
    registered = _register(client)
    token = registered["access_token"]
    child = _create_child(client, token)
    content = asyncio.run(seed_content())

    session_response = client.post(
        "/api/v1/reading/sessions",
        headers={"Authorization": f"Bearer {token}"},
        json={"child_id": child["id"], "book_id": content["book_id"]},
    )
    assert session_response.status_code == 201
    session_id = session_response.json()["id"]

    event_response = client.post(
        "/api/v1/reading/events",
        headers={"Authorization": f"Bearer {token}"},
        json={"session_id": session_id, "event_type": "WORD_CLICK", "word": "cute"},
    )
    assert event_response.status_code == 201

    review_response = client.get(
        f"/api/v1/children/{child['id']}/review",
        headers={"Authorization": f"Bearer {token}"},
    )
    assert review_response.status_code == 200
    words = review_response.json()
    assert len(words) == 1
    assert words[0]["word"] == "cute"

    submit_response = client.post(
        f"/api/v1/children/{child['id']}/review",
        headers={"Authorization": f"Bearer {token}"},
        json={"word_id": words[0]["word_id"], "correct": True},
    )
    assert submit_response.status_code == 200
    assert submit_response.json()["review_stage"] == 1
    assert submit_response.json()["mastered"] is False

    due_after = client.get(
        f"/api/v1/children/{child['id']}/review",
        headers={"Authorization": f"Bearer {token}"},
    )
    assert due_after.status_code == 200
    assert due_after.json() == []


def test_parent_stats_aggregate_weekly_data(client, seed_content):
    registered = _register(client)
    token = registered["access_token"]
    child = _create_child(client, token)
    content = asyncio.run(seed_content())

    session_response = client.post(
        "/api/v1/reading/sessions",
        headers={"Authorization": f"Bearer {token}"},
        json={"child_id": child["id"], "book_id": content["book_id"]},
    )
    assert session_response.status_code == 201
    session_id = session_response.json()["id"]

    event_response = client.post(
        "/api/v1/reading/events",
        headers={"Authorization": f"Bearer {token}"},
        json={"session_id": session_id, "event_type": "WORD_CLICK", "word": "cute"},
    )
    assert event_response.status_code == 201

    finish_response = client.post(
        f"/api/v1/reading/sessions/{session_id}/finish",
        headers={"Authorization": f"Bearer {token}"},
        json={"duration_seconds": 180, "progress": 1.0, "completed": True},
    )
    assert finish_response.status_code == 200

    stats_response = client.get(
        f"/api/v1/children/{child['id']}/stats",
        headers={"Authorization": f"Bearer {token}"},
    )
    assert stats_response.status_code == 200
    body = stats_response.json()
    assert body["child"]["name"] == "小明"
    assert body["weekly"]["books_read"] == 1
    assert body["weekly"]["reading_minutes"] == 3
    assert body["weekly"]["new_words"] == 1
    assert body["quiz_accuracy"] == 0.0
    assert body["word_mastery"] == 0.0
    assert [item["word"] for item in body["attention_words"]] == ["cute"]


def test_reading_progress_counts_partial_duration(client, seed_content):
    registered = _register(client)
    token = registered["access_token"]
    child = _create_child(client, token)
    content = asyncio.run(seed_content())

    session_response = client.post(
        "/api/v1/reading/sessions",
        headers={"Authorization": f"Bearer {token}"},
        json={"child_id": child["id"], "book_id": content["book_id"]},
    )
    assert session_response.status_code == 201
    session_id = session_response.json()["id"]

    progress_response = client.post(
        f"/api/v1/reading/sessions/{session_id}/progress",
        headers={"Authorization": f"Bearer {token}"},
        json={"duration_seconds": 90, "progress": 0.5},
    )
    assert progress_response.status_code == 200
    assert progress_response.json()["duration_seconds"] == 90
    assert progress_response.json()["progress"] == 0.5

    home_response = client.get(
        f"/api/v1/home?child_id={child['id']}",
        headers={"Authorization": f"Bearer {token}"},
    )
    assert home_response.status_code == 200
    assert home_response.json()["today"]["reading_minutes"] == 1

    stats_response = client.get(
        f"/api/v1/children/{child['id']}/stats",
        headers={"Authorization": f"Bearer {token}"},
    )
    assert stats_response.status_code == 200
    assert stats_response.json()["weekly"]["reading_minutes"] == 1
    assert stats_response.json()["weekly"]["books_read"] == 0


def test_create_book_splits_chapters(client):
    registered = _register(client)
    token = registered["access_token"]

    content = (
        "Chapter 1\n"
        "This is page one.\n\n"
        "This is page two.\n\n"
        "Chapter 2\n"
        "This is chapter two text."
    )
    create_response = client.post(
        "/api/v1/books",
        headers={"Authorization": f"Bearer {token}"},
        json={
            "title": "Chaptered Story",
            "level": "LEVEL_2",
            "content": content,
            "questions": [
                {
                    "question": "What is in chapter one?",
                    "correct_option": "A",
                    "options": [
                        {"option_key": "A", "content": "Pages"},
                        {"option_key": "B", "content": "Nothing"},
                    ],
                    "chapter_index": 0,
                }
            ],
        },
    )
    assert create_response.status_code == 201, create_response.text
    book_id = create_response.json()["id"]

    detail_response = client.get(
        f"/api/v1/books/{book_id}",
        headers={"Authorization": f"Bearer {token}"},
    )
    assert detail_response.status_code == 200
    chapters = detail_response.json()["chapters"]
    assert [chapter["index"] for chapter in chapters] == [0, 1]
    assert chapters[0]["title"] == "Chapter 1"
    assert chapters[1]["title"] == "Chapter 2"

    chapter_response = client.get(
        f"/api/v1/books/{book_id}/chapters/0",
        headers={"Authorization": f"Bearer {token}"},
    )
    assert chapter_response.status_code == 200
    segments = chapter_response.json()["segments"]
    assert all(segment["chapter_index"] == 0 for segment in segments)
    assert segments[0]["chapter_title"] == "Chapter 1"

    quiz_response = client.get(
        f"/api/v1/books/{book_id}/quiz",
        headers={"Authorization": f"Bearer {token}"},
    )
    assert quiz_response.status_code == 200
    question = quiz_response.json()[0]
    assert question["chapter_index"] == 0
    assert question["chapter_title"] == "Chapter 1"


def test_generate_quiz_uses_book_chapters(client, monkeypatch):
    from app.ai.mock_provider import MockProvider

    monkeypatch.setattr("app.services.ai_service.get_ai_provider", lambda: MockProvider())
    registered = _register(client)
    token = registered["access_token"]

    create_response = client.post(
        "/api/v1/books/import",
        headers={"Authorization": f"Bearer {token}"},
        json={
            "title": "Four Chapter Book",
            "level": "LEVEL_3",
            "chapters": [
                {"title": "正文", "content": "Once upon a time."},
                {"title": "2", "content": "Then something happened."},
                {"title": "3", "content": "The story continued."},
                {"title": "4", "content": "The story ended."},
            ],
            "questions": [],
        },
    )
    assert create_response.status_code == 201, create_response.text
    book_id = create_response.json()["id"]

    response = client.post(
        "/api/v1/ai/generate-quiz",
        headers={"Authorization": f"Bearer {token}"},
        json={"book_id": book_id},
    )
    assert response.status_code == 200, response.text
    questions = response.json()["questions"]
    assert len(questions) == 12
    assert {q["chapter_index"] for q in questions} == {0, 1, 2, 3}


def test_generate_quiz_per_chapter(client, monkeypatch):
    from app.ai.mock_provider import MockProvider

    monkeypatch.setattr("app.services.ai_service.get_ai_provider", lambda: MockProvider())

    registered = _register(client)
    token = registered["access_token"]

    content = "Chapter 1\nOnce upon a time.\n\nChapter 2\nThe end."
    response = client.post(
        "/api/v1/ai/generate-quiz",
        headers={"Authorization": f"Bearer {token}"},
        json={"text": content},
    )
    assert response.status_code == 200, response.text
    questions = response.json()["questions"]
    assert len(questions) == 6
    assert all(q["chapter_index"] == 0 for q in questions[:3])
    assert all(q["chapter_index"] == 1 for q in questions[3:])
    assert questions[0]["chapter_title"] == "Chapter 1"
    assert questions[3]["chapter_title"] == "Chapter 2"


def test_book_content_preview_and_delete(client):
    registered = _register(client)
    token = registered["access_token"]
    child = _create_child(client, token)

    create_response = client.post(
        "/api/v1/books",
        headers={"Authorization": f"Bearer {token}"},
        json={"title": "Preview Book", "level": "LEVEL_2", "content": "This is the first page of content.\n\nSecond page content."},
    )
    assert create_response.status_code == 201
    book_id = create_response.json()["id"]

    books_response = client.get("/api/v1/books", headers={"Authorization": f"Bearer {token}"})
    assert books_response.status_code == 200
    created = next(book for book in books_response.json() if book["id"] == book_id)
    assert created["content_preview"] == "This is the first page of content. Second page content."

    session_response = client.post(
        "/api/v1/reading/sessions",
        headers={"Authorization": f"Bearer {token}"},
        json={"child_id": child["id"], "book_id": book_id},
    )
    assert session_response.status_code == 201

    delete_response = client.delete(
        f"/api/v1/books/{book_id}",
        headers={"Authorization": f"Bearer {token}"},
    )
    assert delete_response.status_code == 204

    detail_response = client.get(
        f"/api/v1/books/{book_id}",
        headers={"Authorization": f"Bearer {token}"},
    )
    assert detail_response.status_code == 404

def test_create_book_segments_long_content(client):
    registered = _register(client)
    token = registered["access_token"]

    content = " ".join(["word"] * 300)
    create_response = client.post(
        "/api/v1/books",
        headers={"Authorization": f"Bearer {token}"},
        json={"title": "Long Book", "level": "LEVEL_2", "content": content},
    )
    assert create_response.status_code == 201
    book_id = create_response.json()["id"]

    detail_response = client.get(
        f"/api/v1/books/{book_id}",
        headers={"Authorization": f"Bearer {token}"},
    )
    assert detail_response.status_code == 200
    assert len(detail_response.json()["chapters"]) == 1

    chapter_response = client.get(
        f"/api/v1/books/{book_id}/chapters/0",
        headers={"Authorization": f"Bearer {token}"},
    )
    assert chapter_response.status_code == 200
    segments = chapter_response.json()["segments"]
    assert [len(segment["content"].split()) for segment in segments] == [140, 140, 20]


def test_create_book_detects_bare_chapter_numbers(client):
    registered = _register(client)
    token = registered["access_token"]

    content = "I\nThe first chapter.\n\nII\nThe second chapter."
    create_response = client.post(
        "/api/v1/books",
        headers={"Authorization": f"Bearer {token}"},
        json={"title": "Numbered Book", "level": "LEVEL_2", "content": content},
    )
    assert create_response.status_code == 201
    book_id = create_response.json()["id"]

    detail_response = client.get(
        f"/api/v1/books/{book_id}",
        headers={"Authorization": f"Bearer {token}"},
    )
    assert detail_response.status_code == 200
    titles = [chapter["title"] for chapter in detail_response.json()["chapters"]]
    assert titles == ["I", "II"]

def test_preview_drops_front_matter(client):
    registered = _register(client)
    token = registered["access_token"]

    content = "Dedication text.\n\n[ Chapter 1 ]\nThe story begins.\n\n[ Chapter 2 ]\nThe end."
    response = client.post(
        "/api/v1/books/preview",
        headers={"Authorization": f"Bearer {token}"},
        json={"content": content},
    )
    assert response.status_code == 200
    chapters = response.json()["chapters"]
    assert [chapter["title"] for chapter in chapters] == ["Chapter 1", "Chapter 2"]
    assert chapters[0]["content"] == "The story begins."
    assert chapters[1]["content"] == "The end."

def test_import_parse_txt(client):
    registered = _register(client)
    token = registered["access_token"]

    response = client.post(
        "/api/v1/books/import/parse",
        headers={"Authorization": f"Bearer {token}"},
        files={"file": ("book.txt", b"[ Chapter 1 ]\nhello world.\n\n[ Chapter 2 ]\nbye.", "text/plain")},
    )
    assert response.status_code == 200
    chapters = response.json()["chapters"]
    assert [chapter["title"] for chapter in chapters] == ["Chapter 1", "Chapter 2"]


def test_import_book_from_chapters(client):
    registered = _register(client)
    token = registered["access_token"]

    response = client.post(
        "/api/v1/books/import",
        headers={"Authorization": f"Bearer {token}"},
        json={
            "title": "Imported Book",
            "level": "LEVEL_2",
            "chapters": [
                {"title": "Chapter 1", "content": "First chapter text."},
                {"title": "Chapter 2", "content": "Second chapter text."},
            ],
        },
    )
    assert response.status_code == 201
    book_id = response.json()["id"]

    detail = client.get(
        f"/api/v1/books/{book_id}",
        headers={"Authorization": f"Bearer {token}"},
    )
    assert detail.status_code == 200
    assert [chapter["title"] for chapter in detail.json()["chapters"]] == ["Chapter 1", "Chapter 2"]


def test_parse_pdf_uses_toc():
    import fitz

    doc = fitz.open()
    page1 = doc.new_page()
    page1.insert_text((72, 72), "Hello from chapter one.")
    page2 = doc.new_page()
    page2.insert_text((72, 72), "Hello from chapter two.")
    doc.set_toc([[1, "Chapter 1", 1], [1, "Chapter 2", 2]])
    data = doc.tobytes()
    doc.close()

    from app.services.import_service import _parse_pdf

    chapters = _parse_pdf(data)
    assert [chapter.title for chapter in chapters] == ["Chapter 1", "Chapter 2"]

def test_parse_pdf_splits_by_content_not_page_bleed():
    import fitz

    doc = fitz.open()
    page1 = doc.new_page()
    page1.insert_textbox(
        fitz.Rect(50, 50, 500, 700),
        "Front matter for the whole book.\n[ Chapter 1 ]\nChapter one body.\nClosing line of chapter one.",
    )
    page2 = doc.new_page()
    page2.insert_textbox(
        fitz.Rect(50, 50, 500, 700),
        "[ Chapter 2 ]\nChapter two body.",
    )
    doc.set_toc([[1, "Chapter 1", 1], [1, "Chapter 2", 2]])
    data = doc.tobytes()
    doc.close()

    from app.services.import_service import _parse_pdf

    chapters = _parse_pdf(data)
    assert len(chapters) == 2
    assert [chapter.title for chapter in chapters] == ["Chapter 1", "Chapter 2"]
    assert chapters[0].content.startswith("Chapter one body.")
    assert "Front matter" not in chapters[0].content
    assert "Closing line of chapter one." in chapters[0].content
    assert "Closing line of chapter one." not in chapters[1].content
    assert chapters[1].content.startswith("Chapter two body.")

def test_extract_json_handles_markdown_fence():
    from app.ai.base import extract_json

    raw = (
        '```json\n'
        '{"questions": [{"question": "What is it?", "correct_option": "A", '
        '"options": [{"option_key": "A", "content": "A thing"}]}]}\n'
        '```'
    )
    data = extract_json(raw)
    assert data["questions"][0]["question"] == "What is it?"


def test_favorite_word(client):
    registered = _register(client)
    token = registered["access_token"]
    child = _create_child(client, token)

    response = client.post(
        f"/api/v1/children/{child['id']}/words/cute/favorite",
        headers={"Authorization": f"Bearer {token}"},
        json={"favorite": True},
    )
    assert response.status_code == 200, response.text
    assert response.json()["favorite"] is True
    assert response.json()["word"]["word"] == "cute"

    vocabulary = client.get(
        f"/api/v1/children/{child['id']}/words",
        headers={"Authorization": f"Bearer {token}"},
    )
    assert vocabulary.status_code == 200
    cute = next(item for item in vocabulary.json() if item["word"]["word"] == "cute")
    assert cute["favorite"] is True

    unfavorite = client.post(
        f"/api/v1/children/{child['id']}/words/cute/favorite",
        headers={"Authorization": f"Bearer {token}"},
        json={"favorite": False},
    )
    assert unfavorite.status_code == 200
    assert unfavorite.json()["favorite"] is False


def test_key_items_uses_mock_provider(client, monkeypatch):
    from app.ai.mock_provider import MockProvider

    monkeypatch.setattr("app.services.ai_service.get_ai_provider", lambda: MockProvider())

    registered = _register(client)
    token = registered["access_token"]

    response = client.post(
        "/api/v1/ai/key-items",
        headers={"Authorization": f"Bearer {token}"},
        json={"text": "The dog is very cute."},
    )
    assert response.status_code == 200, response.text
    items = response.json()["items"]
    assert len(items) >= 1
    assert items[0]["term"] == "dog"
    assert items[0]["meaning_zh"] == "（示例释义）"
    assert all(item["term"] not in {"the", "is", "a"} for item in items)


def test_key_items_excludes_stopwords_and_caps_items(client, monkeypatch):
    from app.ai.mock_provider import MockProvider

    text = " ".join(f"word{i}" for i in range(300))

    class NoisyProvider(MockProvider):
        async def extract_key_items(self, text):
            items = [{"term": f"word{i}", "phonetic": f"/{i}/", "meaning_zh": "（示例释义）", "simple_definition": "example"} for i in range(20)]
            items.append({"term": "the", "phonetic": "/the/", "meaning_zh": "这", "simple_definition": "function word"})
            return items

    monkeypatch.setattr("app.services.ai_service.get_ai_provider", lambda: NoisyProvider())
    registered = _register(client)
    token = registered["access_token"]

    response = client.post(
        "/api/v1/ai/key-items",
        headers={"Authorization": f"Bearer {token}"},
        json={"text": text},
    )
    assert response.status_code == 200, response.text
    items = response.json()["items"]
    assert 1 <= len(items) <= 20
    assert all(item["term"] != "the" for item in items)


def test_chapter_key_items_are_cached(client, seed_content, monkeypatch):
    from app.ai.mock_provider import MockProvider

    monkeypatch.setattr("app.services.ai_service.get_ai_provider", lambda: MockProvider())

    registered = _register(client)
    token = registered["access_token"]
    content = asyncio.run(seed_content())

    url = f"/api/v1/books/{content['book_id']}/chapters/0/key-items"
    first = client.get(url, headers={"Authorization": f"Bearer {token}"})
    assert first.status_code == 200, first.text
    items = first.json()["items"]
    assert len(items) >= 1
    assert "phonetic" in items[0]

    second = client.get(url, headers={"Authorization": f"Bearer {token}"})
    assert second.status_code == 200
    assert second.json()["items"] == items


def test_add_question_to_existing_book(client, seed_content):
    registered = _register(client)
    token = registered["access_token"]
    content = asyncio.run(seed_content())

    response = client.post(
        f"/api/v1/books/{content['book_id']}/quiz",
        headers={"Authorization": f"Bearer {token}"},
        json={
            "question": "Where is the dog?",
            "correct_option": "B",
            "chapter_index": 0,
            "options": [
                {"option_key": "A", "content": "In the park"},
                {"option_key": "B", "content": "At home"},
                {"option_key": "C", "content": "At school"},
            ],
        },
    )
    assert response.status_code == 201, response.text
    created = response.json()
    assert created["question"] == "Where is the dog?"
    assert created["chapter_index"] == 0
    assert len(created["options"]) == 3

    quiz = client.get(
        f"/api/v1/books/{content['book_id']}/quiz",
        headers={"Authorization": f"Bearer {token}"},
    )
    assert quiz.status_code == 200
    quiz_items = quiz.json()
    assert len(quiz_items) == 2
    assert any(item["question"] == "Where is the dog?" for item in quiz_items)


def test_get_word_status(client):
    registered = _register(client)
    token = registered["access_token"]
    child = _create_child(client, token)

    missing = client.get(
        f"/api/v1/children/{child['id']}/words/cute",
        headers={"Authorization": f"Bearer {token}"},
    )
    assert missing.status_code == 404

    fav = client.post(
        f"/api/v1/children/{child['id']}/words/cute/favorite",
        headers={"Authorization": f"Bearer {token}"},
        json={"favorite": True},
    )
    assert fav.status_code == 200

    status_resp = client.get(
        f"/api/v1/children/{child['id']}/words/cute",
        headers={"Authorization": f"Bearer {token}"},
    )
    assert status_resp.status_code == 200
    assert status_resp.json()["mastered"] is False


def test_judge_answer_uses_mock_provider(client, monkeypatch):
    from app.ai.mock_provider import MockProvider

    monkeypatch.setattr("app.services.ai_service.get_ai_provider", lambda: MockProvider())

    registered = _register(client)
    token = registered["access_token"]

    response = client.post(
        "/api/v1/ai/judge-answer",
        headers={"Authorization": f"Bearer {token}"},
        json={
            "question": "What does Tom have?",
            "student_answer": "Tom has a little dog.",
            "reference_answer": "Tom has a little dog.",
        },
    )
    assert response.status_code == 200, response.text
    body = response.json()
    assert body["correct"] is True
    assert "答对" in body["feedback"]
    assert body["model_answer"] == "Tom has a little dog."


def test_judge_read_aloud_accepts_close_match(client):
    registered = _register(client)
    token = registered["access_token"]

    response = client.post(
        "/api/v1/ai/judge-read-aloud",
        headers={"Authorization": f"Bearer {token}"},
        json={
            "target_sentence": "The dog is very cute.",
            "student_transcript": "The dog is very cute.",
        },
    )
    assert response.status_code == 200, response.text
    body = response.json()
    assert body["correct"] is True
    assert body["feedback"]


def test_voice_quiz_attempt_records_result(client, seed_content, monkeypatch):
    from app.ai.mock_provider import MockProvider

    monkeypatch.setattr("app.services.ai_service.get_ai_provider", lambda: MockProvider())

    registered = _register(client)
    token = registered["access_token"]
    child = _create_child(client, token)
    content = asyncio.run(seed_content())

    quiz_response = client.get(
        f"/api/v1/books/{content['book_id']}/quiz",
        headers={"Authorization": f"Bearer {token}"},
    )
    question = quiz_response.json()[0]

    response = client.post(
        "/api/v1/quiz/voice-attempt",
        headers={"Authorization": f"Bearer {token}"},
        json={
            "child_id": child["id"],
            "question_id": question["id"],
            "student_answer": "Tom has a little dog.",
        },
    )
    assert response.status_code == 201, response.text
    body = response.json()
    assert body["is_correct"] is True
    assert body["correct_option"] == "A"


class _FakeTtsProvider:
    async def synthesize(self, text: str, language_code: str = "en-US"):
        return b"fake-audio", "audio/mpeg"


def test_tts_synthesize_uses_provider(client, monkeypatch):
    monkeypatch.setattr("app.api.tts.get_tts_provider", lambda: _FakeTtsProvider())

    registered = _register(client)
    token = registered["access_token"]

    response = client.post(
        "/api/v1/tts/synthesize",
        headers={"Authorization": f"Bearer {token}"},
        json={"text": "hello", "language_code": "en-US"},
    )
    assert response.status_code == 200, response.text
    body = response.json()
    assert body["audio_base64"] == "ZmFrZS1hdWRpbw=="
    assert body["mime_type"] == "audio/mpeg"


class _FakeAsrProvider:
    async def transcribe(self, audio: bytes, mime_type: str):
        return "Tom has a little dog."


def test_asr_transcribe_uses_provider(client, monkeypatch):
    monkeypatch.setattr("app.api.asr.get_asr_provider", lambda: _FakeAsrProvider())

    registered = _register(client)
    token = registered["access_token"]

    response = client.post(
        "/api/v1/asr/transcribe",
        headers={"Authorization": f"Bearer {token}"},
        json={
            "audio_base64": base64.b64encode(b"fake-audio").decode(),
            "mime_type": "audio/webm",
        },
    )
    assert response.status_code == 200, response.text
    assert response.json()["transcript"] == "Tom has a little dog."


def test_asr_transcribe_requires_auth(client):
    response = client.post(
        "/api/v1/asr/transcribe",
        json={"audio_base64": base64.b64encode(b"fake-audio").decode()},
    )
    assert response.status_code == 401


class _FakeGoogleResponse:
    def __init__(self, data):
        self._data = data

    def raise_for_status(self):
        return None

    def json(self):
        return self._data


class _FakeGoogleAsyncClient:
    captured_payload = None
    captured_headers = None

    def __init__(self, timeout=None):
        pass

    async def __aenter__(self):
        return self

    async def __aexit__(self, *args):
        return False

    async def post(self, url, headers=None, json=None):
        type(self).captured_payload = json
        type(self).captured_headers = headers
        return _FakeGoogleResponse(
            {"audioContent": base64.b64encode(b"fake-audio").decode()}
        )


def test_google_tts_journey_uses_wav_and_omits_rate_and_pitch(monkeypatch):
    from app.tts.google_provider import GoogleTtsProvider

    monkeypatch.setattr(
        "app.tts.google_provider.httpx2.AsyncClient",
        _FakeGoogleAsyncClient,
    )
    _FakeGoogleAsyncClient.captured_payload = None

    provider = GoogleTtsProvider(
        api_key="key",
        voice="en-US-Journey-O",
        speaking_rate=0.85,
        pitch=0.0,
    )
    audio, mime_type = asyncio.run(provider.synthesize("Hello world."))

    assert audio == b"fake-audio"
    assert mime_type == "audio/wav"
    config = _FakeGoogleAsyncClient.captured_payload["audioConfig"]
    assert config["audioEncoding"] == "LINEAR16"
    assert "speakingRate" not in config
    assert "pitch" not in config


def test_google_tts_neural2_uses_mp3_and_rate_and_pitch(monkeypatch):
    from app.tts.google_provider import GoogleTtsProvider

    monkeypatch.setattr(
        "app.tts.google_provider.httpx2.AsyncClient",
        _FakeGoogleAsyncClient,
    )
    _FakeGoogleAsyncClient.captured_payload = None

    provider = GoogleTtsProvider(
        api_key="key",
        voice="en-US-Neural2-C",
        speaking_rate=0.95,
        pitch=0.0,
    )
    audio, mime_type = asyncio.run(provider.synthesize("Hello world."))

    assert audio == b"fake-audio"
    assert mime_type == "audio/mpeg"
    config = _FakeGoogleAsyncClient.captured_payload["audioConfig"]
    assert config["audioEncoding"] == "MP3"
    assert config["speakingRate"] == 0.95
    assert config["pitch"] == 0.0

def test_google_tts_prefers_oauth_bearer(monkeypatch):
    from app.tts.google_provider import GoogleTtsProvider

    monkeypatch.setattr(
        "app.tts.google_provider.httpx2.AsyncClient",
        _FakeGoogleAsyncClient,
    )
    _FakeGoogleAsyncClient.captured_payload = None
    _FakeGoogleAsyncClient.captured_headers = None

    provider = GoogleTtsProvider(
        api_key="legacy-key",
        access_token="oauth-token",
        voice="en-US-Journey-O",
    )
    asyncio.run(provider.synthesize("Hello world."))

    headers = _FakeGoogleAsyncClient.captured_headers
    assert headers["Authorization"] == "Bearer oauth-token"
    assert "X-Goog-Api-Key" not in headers