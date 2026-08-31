import asyncio


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
    assert len(detail_response.json()["pages"]) == 3

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