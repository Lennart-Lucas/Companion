import pytest
from pydantic import ValidationError

from app.schemas.media_title import MediaTitleCreate


def test_media_title_create_accepts_valid_imdb_id():
    payload = MediaTitleCreate(imdb_id="tt1375666")
    assert payload.imdb_id == "tt1375666"


def test_media_title_create_rejects_invalid_imdb_id():
    with pytest.raises(ValidationError):
        MediaTitleCreate(imdb_id="invalid")
