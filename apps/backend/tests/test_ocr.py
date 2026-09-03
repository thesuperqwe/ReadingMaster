import base64


class _FakeOcrProvider:
    async def recognize(self, images):
        return "Chapter One\n\nThe dog is very cute.\n\nTom has a little dog."


def test_ocr_import_uses_provider(client, monkeypatch):
    monkeypatch.setattr("app.api.books.get_ocr_provider", lambda: _FakeOcrProvider())

    registered = client.post(
        "/api/v1/auth/register",
        json={"email": "parent@example.com", "password": "secret123"},
    )
    assert registered.status_code == 201, registered.text
    token = registered.json()["access_token"]

    response = client.post(
        "/api/v1/books/import/ocr",
        headers={"Authorization": f"Bearer {token}"},
        json={
            "images": [
                {
                    "data": base64.b64encode(b"fake-image").decode(),
                    "mime_type": "image/jpeg",
                }
            ]
        },
    )
    assert response.status_code == 200, response.text
    body = response.json()
    assert body["chapters"]
    assert body["chapters"][0]["content"]


def test_ocr_import_requires_auth(client):
    response = client.post(
        "/api/v1/books/import/ocr",
        json={"images": [{"data": base64.b64encode(b"x").decode()}]},
    )
    assert response.status_code == 401
