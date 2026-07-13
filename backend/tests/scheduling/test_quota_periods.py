from datetime import UTC, datetime

from app.scheduling.quota_periods import (
    first_quota_period_start,
    iter_quota_periods,
    quota_period_bounds,
    quota_period_end_date,
)


def test_first_period_starts_monday_of_start_week():
    # Thursday 21 May 2026
    start = datetime(2026, 5, 21, 9, 0, tzinfo=UTC)
    monday = first_quota_period_start(start, "UTC")
    assert monday == datetime(2026, 5, 18).date()


def test_two_week_period_ends_on_second_sunday():
    start = datetime(2026, 5, 21, 9, 0, tzinfo=UTC)
    period = quota_period_bounds(
        start,
        period_weeks=2,
        period_index=0,
        dtstart=datetime(2026, 5, 21, 9, 0, tzinfo=UTC),
        timezone="UTC",
    )
    assert period.start_at == datetime(2026, 5, 18, 9, 0, tzinfo=UTC)
    assert period.end_at == datetime(2026, 5, 31, 9, 0, tzinfo=UTC)
    assert quota_period_end_date(
        first_quota_period_start(start, "UTC"), period_weeks=2
    ) == datetime(2026, 5, 31).date()


def test_iter_quota_periods_overlaps_window():
    entity_start = datetime(2026, 5, 21, 9, 0, tzinfo=UTC)
    periods = iter_quota_periods(
        entity_start,
        period_weeks=2,
        window_start=datetime(2026, 6, 1, tzinfo=UTC),
        window_end=datetime(2026, 6, 15, tzinfo=UTC),
        entity_end=None,
        dtstart=entity_start,
        timezone="UTC",
    )
    assert len(periods) >= 1
    assert periods[0].start_at <= datetime(2026, 6, 15, tzinfo=UTC)
