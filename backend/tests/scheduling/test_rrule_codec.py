from datetime import UTC, datetime

import pytest

from app.scheduling.rrule_codec import (
    PATTERN_EVERY_N_DAYS,
    PATTERN_EVERY_N_WEEKS,
    PATTERN_MONTH_DAYS,
    PATTERN_WEEKDAYS,
    is_recurring,
    pattern_to_rrule,
    rrule_to_pattern,
    validate_rrule,
)


class TestRruleCodec:
    def test_daily_pattern(self):
        rrule = pattern_to_rrule(PATTERN_EVERY_N_DAYS, interval=2)
        assert rrule == "FREQ=DAILY;INTERVAL=2"
        assert rrule_to_pattern(rrule).pattern == PATTERN_EVERY_N_DAYS
        assert rrule_to_pattern(rrule).interval == 2

    def test_weekly_pattern(self):
        rrule = pattern_to_rrule(PATTERN_EVERY_N_WEEKS, interval=3)
        assert rrule == "FREQ=WEEKLY;INTERVAL=3"
        assert rrule_to_pattern(rrule).pattern == PATTERN_EVERY_N_WEEKS

    def test_weekdays_pattern(self):
        rrule = pattern_to_rrule(
            PATTERN_WEEKDAYS, interval=2, weekdays=[1, 3]
        )
        assert rrule == "FREQ=WEEKLY;INTERVAL=2;BYDAY=MO,WE"
        decoded = rrule_to_pattern(rrule)
        assert decoded.pattern == PATTERN_WEEKDAYS
        assert decoded.weekdays == [1, 3]

    def test_month_days_pattern(self):
        rrule = pattern_to_rrule(
            PATTERN_MONTH_DAYS, interval=1, month_days=[1, 20]
        )
        assert rrule == "FREQ=MONTHLY;INTERVAL=1;BYMONTHDAY=1,20"
        decoded = rrule_to_pattern(rrule)
        assert decoded.pattern == PATTERN_MONTH_DAYS
        assert decoded.month_days == [1, 20]

    def test_is_recurring(self):
        assert is_recurring("FREQ=DAILY;INTERVAL=1", None) is True
        assert is_recurring(None, []) is False
        assert is_recurring(None, [datetime(2026, 1, 1).date()]) is True
        assert is_recurring(None, None, quota_times=3, quota_period_weeks=2) is True

    def test_validate_rrule_rejects_invalid(self):
        with pytest.raises(ValueError):
            validate_rrule("FREQ=NOTREAL")

    def test_until_appended(self):
        until = datetime(2026, 12, 31, 23, 59, tzinfo=UTC)
        rrule = pattern_to_rrule(
            PATTERN_EVERY_N_DAYS, interval=1, until=until
        )
        assert "UNTIL=" in rrule
        validate_rrule(rrule.split(";UNTIL=")[0])
