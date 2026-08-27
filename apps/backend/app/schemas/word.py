from pydantic import BaseModel, ConfigDict


class WordOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    word: str
    phonetic: str | None
    meaning_zh: str | None
    simple_definition: str | None
    example_sentence: str | None
    example_translation: str | None
    audio_url: str | None
    part_of_speech: str | None


class UserWordOut(BaseModel):
    word: WordOut
    mastery_score: float
    encounter_count: int
    click_count: int
    audio_count: int
    correct_count: int
    wrong_count: int
