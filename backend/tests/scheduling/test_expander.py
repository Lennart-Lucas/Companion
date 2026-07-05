from datetime import UTC, date, datetime
from zoneinfo import ZoneInfo

import pytest

from app.scheduling.expander import (
    end_datetime_before_occurrence,
    ensure_dtstart_occurrence,
    expand_occurrences,
    schedule_local_date,
)
from app.scheduling.types import (
    OverrideScope,
    ScheduleBundle,
    ScheduleOverrideData,
)
from app.scheduling.validators import (
    ScheduleValidationError,
    validate_schedule_payload,
    validate_timezone,
)


def _dt(year: int, month: int, day: int, hour: int = 9, minute: int = 0) -> datetime:
    return datetime(year, month, day, hour, minute, tzinfo=ZoneInfo("Europe/Amsterdam"))


def _window(start: datetime, days: int = 60) -> tuple[datetime, datetime]:
    end = start + __import__("datetime").timedelta(days=days)
    return start.astimezone(UTC), end.astimezone(UTC)


class TestValidators:
    def test_valid_timezone(self):
        validate_timezone("Europe/Amsterdam")

    def test_invalid_timezone(self):
        with pytest.raises(ScheduleValidationError):
            validate_timezone("Not/AZone")

    def test_invalid_rrule(self):
        with pytest.raises(ScheduleValidationError):
            validate_schedule_payload(
                rrule="FREQ=NOTREAL",
                rdates=None,
                exdates=None,
                timezone="UTC",
            )


class TestRepeatNone:
    def test_single_occurrence_in_window(self):
        dtstart = _dt(2026, 5, 21)
        bundle = ScheduleBundle(
            dtstart=dtstart,
            timezone="Europe/Amsterdam",
        )
        start, end = _window(dtstart)
        result = expand_occurrences(bundle, start=start, end=end)
        assert len(result) == 1
        assert result[0] == dtstart.astimezone(UTC)

    def test_outside_window(self):
        dtstart = _dt(2026, 5, 21)
        bundle = ScheduleBundle(
            dtstart=dtstart,
            timezone="Europe/Amsterdam",
        )
        start = datetime(2026, 6, 1, tzinfo=UTC)
        end = datetime(2026, 6, 30, tzinfo=UTC)
        assert expand_occurrences(bundle, start=start, end=end) == []


class TestEveryNDays:
    def test_every_2_days(self):
        dtstart = _dt(2026, 5, 21)
        bundle = ScheduleBundle(
            dtstart=dtstart,
            timezone="Europe/Amsterdam",
            rrule="FREQ=DAILY;INTERVAL=2",
        )
        start, end = _window(dtstart, days=10)
        result = expand_occurrences(bundle, start=start, end=end, max_count=10)
        assert len(result) >= 5
        deltas = [
            (result[i + 1] - result[i]).days for i in range(len(result) - 1)
        ]
        assert all(d == 2 for d in deltas)


class TestEveryNWeeks:
    def test_every_week(self):
        dtstart = _dt(2026, 5, 21)
        bundle = ScheduleBundle(
            dtstart=dtstart,
            timezone="Europe/Amsterdam",
            rrule="FREQ=WEEKLY;INTERVAL=1",
        )
        start, end = _window(dtstart, days=30)
        result = expand_occurrences(bundle, start=start, end=end, max_count=5)
        assert len(result) == 5


class TestWeekdays:
    def test_mon_wed_every_2_weeks(self):
        dtstart = _dt(2026, 5, 21)
        bundle = ScheduleBundle(
            dtstart=dtstart,
            timezone="Europe/Amsterdam",
            rrule="FREQ=WEEKLY;INTERVAL=2;BYDAY=MO,WE",
        )
        start = datetime(2026, 5, 1, tzinfo=UTC)
        end = datetime(2026, 6, 30, tzinfo=UTC)
        result = expand_occurrences(bundle, start=start, end=end, max_count=20)
        for occ in result:
            local = occ.astimezone(ZoneInfo("Europe/Amsterdam"))
            assert local.isoweekday() in (1, 3)

    def test_ensure_dtstart_includes_start_day_when_pattern_skips_it(self):
        dtstart = _dt(2026, 5, 21)
        bundle = ScheduleBundle(
            dtstart=dtstart,
            timezone="Europe/Amsterdam",
            rrule="FREQ=WEEKLY;INTERVAL=2;BYDAY=MO,WE",
        )
        start = datetime(2026, 5, 1, tzinfo=UTC)
        end = datetime(2026, 6, 30, tzinfo=UTC)
        expanded = expand_occurrences(bundle, start=start, end=end, max_count=20)
        assert schedule_local_date(bundle, expanded[0]) != date(2026, 5, 21)

        result = ensure_dtstart_occurrence(
            bundle,
            expanded,
            start=start,
            end=end,
            max_count=20,
        )
        assert schedule_local_date(bundle, result[0]) == date(2026, 5, 21)
        assert result[0] == dtstart.astimezone(UTC)

    def test_mon_fri_weekly_stays_on_weekdays_in_schedule_timezone(self):
        dtstart = _dt(2026, 5, 18)
        bundle = ScheduleBundle(
            dtstart=dtstart,
            timezone="Europe/Amsterdam",
            rrule="FREQ=WEEKLY;INTERVAL=1;BYDAY=MO,TU,WE,TH,FR",
        )
        start = datetime(2026, 5, 10, tzinfo=UTC)
        end = datetime(2026, 6, 10, tzinfo=UTC)
        expanded = expand_occurrences(bundle, start=start, end=end, max_count=50)
        result = ensure_dtstart_occurrence(
            bundle,
            expanded,
            start=start,
            end=end,
            max_count=50,
        )

        local_dates = [schedule_local_date(bundle, occ) for occ in result]

        assert local_dates[:10] == [
            date(2026, 5, 18),
            date(2026, 5, 19),
            date(2026, 5, 20),
            date(2026, 5, 21),
            date(2026, 5, 22),
            date(2026, 5, 25),
            date(2026, 5, 26),
            date(2026, 5, 27),
            date(2026, 5, 28),
            date(2026, 5, 29),
        ]
        for occ in result:
            assert occ.astimezone(ZoneInfo("Europe/Amsterdam")).isoweekday() in (
                1,
                2,
                3,
                4,
                5,
            )

    def test_ensure_dtstart_uses_anchor_at_not_drifted_dtstart(self):
        dtstart = _dt(2026, 6, 27)
        bundle = ScheduleBundle(
            dtstart=dtstart,
            timezone="Europe/Brussels",
            rrule="FREQ=WEEKLY;INTERVAL=1;BYDAY=MO,TU,WE,TH,FR",
        )
        start = datetime(2026, 6, 20, tzinfo=UTC)
        end = datetime(2026, 7, 10, tzinfo=UTC)
        expanded = expand_occurrences(bundle, start=start, end=end, max_count=50)
        tracker_start = _dt(2026, 6, 26)
        result = ensure_dtstart_occurrence(
            bundle,
            expanded,
            start=start,
            end=end,
            max_count=50,
            anchor_at=tracker_start,
        )

        local_dates = [schedule_local_date(bundle, occ) for occ in result]
        assert date(2026, 6, 27) not in local_dates
        assert date(2026, 6, 26) in local_dates
        assert local_dates[:5] == [
            date(2026, 6, 26),
            date(2026, 6, 29),
            date(2026, 6, 30),
            date(2026, 7, 1),
            date(2026, 7, 2),
        ]

    def test_ensure_dtstart_skips_weekend_for_weekdays_only_pattern(self):
        dtstart = _dt(2026, 6, 27)
        bundle = ScheduleBundle(
            dtstart=dtstart,
            timezone="Europe/Brussels",
            rrule="FREQ=WEEKLY;INTERVAL=1;BYDAY=MO,TU,WE,TH,FR",
        )
        start = datetime(2026, 6, 20, tzinfo=UTC)
        end = datetime(2026, 7, 10, tzinfo=UTC)
        expanded = expand_occurrences(bundle, start=start, end=end, max_count=50)
        result = ensure_dtstart_occurrence(
            bundle,
            expanded,
            start=start,
            end=end,
            max_count=50,
        )

        local_dates = [schedule_local_date(bundle, occ) for occ in result]
        assert date(2026, 6, 27) not in local_dates
        assert local_dates[0] == date(2026, 6, 29)


class TestSpecificDates:
    def test_only_listed_dates(self):
        dtstart = _dt(2026, 5, 21, 14, 30)
        bundle = ScheduleBundle(
            dtstart=dtstart,
            timezone="Europe/Amsterdam",
            rdates=[date(2026, 6, 1), date(2026, 6, 15)],
        )
        start = datetime(2026, 1, 1, tzinfo=UTC)
        end = datetime(2026, 12, 31, tzinfo=UTC)
        result = expand_occurrences(bundle, start=start, end=end)
        assert len(result) == 2
        local_times = [r.astimezone(ZoneInfo("Europe/Amsterdam")) for r in result]
        assert local_times[0].hour == 14 and local_times[0].minute == 30
        assert local_times[0].date() == date(2026, 6, 1)
        assert local_times[1].date() == date(2026, 6, 15)


class TestMonthDays:
    def test_first_and_twentieth(self):
        dtstart = _dt(2026, 5, 21)
        bundle = ScheduleBundle(
            dtstart=dtstart,
            timezone="Europe/Amsterdam",
            rrule="FREQ=MONTHLY;INTERVAL=1;BYMONTHDAY=1,20",
        )
        start = datetime(2026, 5, 1, tzinfo=UTC)
        end = datetime(2026, 7, 31, tzinfo=UTC)
        result = expand_occurrences(bundle, start=start, end=end, max_count=10)
        local_dates = [
            r.astimezone(ZoneInfo("Europe/Amsterdam")).date() for r in result
        ]
        assert all(d.day in (1, 20) for d in local_dates)
        assert local_dates[0] >= date(2026, 5, 1)
        assert local_dates[-1] <= date(2026, 7, 31)


class TestEveryNMonths:
    def test_monthly_on_anchor_day(self):
        dtstart = _dt(2026, 1, 15)
        bundle = ScheduleBundle(
            dtstart=dtstart,
            timezone="Europe/Amsterdam",
            rrule="FREQ=MONTHLY;INTERVAL=1",
        )
        start = datetime(2026, 1, 1, tzinfo=UTC)
        end = datetime(2026, 6, 30, tzinfo=UTC)
        result = expand_occurrences(bundle, start=start, end=end, max_count=6)
        assert len(result) == 6
        for occ in result:
            assert occ.astimezone(ZoneInfo("Europe/Amsterdam")).day == 15


class TestExclusions:
    def test_schedule_local_date_uses_schedule_timezone(self):
        bundle = ScheduleBundle(
            dtstart=datetime(2026, 6, 2, 22, 0, tzinfo=UTC),
            timezone="UTC",
            rrule="FREQ=DAILY;INTERVAL=5",
        )
        occurrence = datetime(2026, 6, 27, 22, 0, tzinfo=UTC)
        assert schedule_local_date(bundle, occurrence) == date(2026, 6, 27)

    def test_end_datetime_before_occurrence_uses_anchor_time(self):
        bundle = ScheduleBundle(
            dtstart=datetime(2026, 6, 2, 22, 0, tzinfo=UTC),
            timezone="UTC",
            rrule="FREQ=DAILY;INTERVAL=5",
        )
        occurrence = datetime(2026, 6, 27, 22, 0, tzinfo=UTC)
        end_dt = end_datetime_before_occurrence(bundle, occurrence)
        assert end_dt == datetime(2026, 6, 26, 22, 0, tzinfo=UTC)

    def test_excluded_date_removed(self):
        dtstart = _dt(2026, 5, 21)
        bundle = ScheduleBundle(
            dtstart=dtstart,
            timezone="Europe/Amsterdam",
            rrule="FREQ=DAILY;INTERVAL=1",
            exclusions={date(2026, 5, 22)},
        )
        start = datetime(2026, 5, 21, tzinfo=UTC)
        end = datetime(2026, 5, 25, tzinfo=UTC)
        result = expand_occurrences(bundle, start=start, end=end, max_count=10)
        local_dates = [
            r.astimezone(ZoneInfo("Europe/Amsterdam")).date() for r in result
        ]
        assert date(2026, 5, 22) not in local_dates


class TestOverrides:
    def test_from_date_uses_replacement(self):
        dtstart = _dt(2026, 5, 21)
        replacement = ScheduleBundle(
            dtstart=_dt(2026, 6, 1),
            timezone="Europe/Amsterdam",
            rrule="FREQ=WEEKLY;INTERVAL=1",
        )
        bundle = ScheduleBundle(
            dtstart=dtstart,
            timezone="Europe/Amsterdam",
            rrule="FREQ=DAILY;INTERVAL=1",
            overrides=[
                ScheduleOverrideData(
                    scope=OverrideScope.from_date,
                    effective_at=_dt(2026, 6, 1),
                    replacement=replacement,
                )
            ],
        )
        start = datetime(2026, 5, 25, tzinfo=UTC)
        end = datetime(2026, 6, 30, tzinfo=UTC)
        result = expand_occurrences(bundle, start=start, end=end, max_count=20)
        before = [r for r in result if r < _dt(2026, 6, 1).astimezone(UTC)]
        after = [r for r in result if r >= _dt(2026, 6, 1).astimezone(UTC)]
        assert len(before) > 0
        assert len(after) > 0

    def test_single_occurrence_override(self):
        dtstart = _dt(2026, 5, 21)
        replacement = ScheduleBundle(
            dtstart=_dt(2026, 5, 22, 15, 0),
            timezone="Europe/Amsterdam",
        )
        bundle = ScheduleBundle(
            dtstart=dtstart,
            timezone="Europe/Amsterdam",
            rrule="FREQ=DAILY;INTERVAL=1",
            overrides=[
                ScheduleOverrideData(
                    scope=OverrideScope.single_occurrence,
                    effective_at=_dt(2026, 5, 22),
                    replacement=replacement,
                )
            ],
        )
        start = datetime(2026, 5, 21, tzinfo=UTC)
        end = datetime(2026, 5, 24, tzinfo=UTC)
        result = expand_occurrences(bundle, start=start, end=end, max_count=10)
        may_22 = [
            r
            for r in result
            if r.astimezone(ZoneInfo("Europe/Amsterdam")).date() == date(2026, 5, 22)
        ]
        assert len(may_22) == 1
        assert may_22[0].astimezone(ZoneInfo("Europe/Amsterdam")).hour == 15
