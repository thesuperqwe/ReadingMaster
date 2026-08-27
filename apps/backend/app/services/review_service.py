import re
import uuid
from datetime import datetime, timedelta, timezone

from fastapi import HTTPException, status
from sqlalchemy import or_, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models import UserWord, Word
from app.schemas.review import ReviewResultOut, ReviewSubmitRequest, ReviewWordOut

REVIEW_INTERVALS_DAYS = [1, 2, 4, 7, 15, 30]


def _make_cloze(sentence: str | None, word: str) -> str | None:
    if not sentence:
        return None
    pattern = re.compile(rf"\b{re.escape(word)}\b", re.IGNORECASE)
    cloze, count = pattern.subn("_____", sentence)
    return cloze if count > 0 else None


async def list_due_review_words(
    session: AsyncSession, child_id: uuid.UUID
) -> list[ReviewWordOut]:
    now = datetime.now(timezone.utc)
    rows = await session.execute(
        select(UserWord, Word)
        .join(Word, Word.id == UserWord.word_id)
        .where(UserWord.child_id == child_id)
        .where(UserWord.mastered.is_(False))
        .where(
            or_(
                UserWord.next_review_at.is_(None),
                UserWord.next_review_at <= now,
            )
        )
        .order_by(UserWord.created_at, Word.word)
    )

    result = []
    for user_word, word in rows:
        result.append(
            ReviewWordOut(
                word_id=user_word.word_id,
                word=word.word,
                phonetic=word.phonetic,
                meaning_zh=word.meaning_zh,
                simple_definition=word.simple_definition,
                example_sentence=word.example_sentence,
                example_translation=word.example_translation,
                part_of_speech=word.part_of_speech,
                cloze=_make_cloze(word.example_sentence, word.word),
            )
        )
    return result


async def submit_review(
    session: AsyncSession, child_id: uuid.UUID, data: ReviewSubmitRequest
) -> ReviewResultOut:
    user_word = await session.scalar(
        select(UserWord).where(
            UserWord.child_id == child_id,
            UserWord.word_id == data.word_id,
        )
    )
    if user_word is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Review word not found",
        )

    now = datetime.now(timezone.utc)
    if data.correct:
        user_word.correct_count += 1
        user_word.review_stage = min(
            user_word.review_stage + 1, len(REVIEW_INTERVALS_DAYS)
        )
        if user_word.review_stage >= len(REVIEW_INTERVALS_DAYS):
            user_word.mastered = True
            user_word.next_review_at = None
        else:
            user_word.next_review_at = now + timedelta(
                days=REVIEW_INTERVALS_DAYS[user_word.review_stage - 1]
            )
    else:
        user_word.wrong_count += 1
        user_word.review_stage = 0
        user_word.mastered = False
        user_word.next_review_at = now + timedelta(days=REVIEW_INTERVALS_DAYS[0])

    user_word.last_seen_at = now
    attempts = user_word.correct_count + user_word.wrong_count
    user_word.mastery_score = round(user_word.correct_count / attempts, 2) if attempts else 0

    await session.commit()
    await session.refresh(user_word)
    return ReviewResultOut(
        word_id=user_word.word_id,
        review_stage=user_word.review_stage,
        next_review_at=user_word.next_review_at,
        mastered=user_word.mastered,
        correct_count=user_word.correct_count,
        wrong_count=user_word.wrong_count,
    )