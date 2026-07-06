from datetime import date

from app.models.check_in_scheduling import QuotaPeriodUnit
from app.scheduling.quota_periods import period_for_date


class TestQuotaPeriods:
    def test_iso_week_period_two_weeks(self):
        # ISO week 2 of 2026 falls in the weeks 1–2 block (starts Mon 2025-12-29).
        day = date(2026, 1, 7)
        period = period_for_date(day, interval=2, unit=QuotaPeriodUnit.weeks)
        assert period.start == date(2025, 12, 29)
        assert period.end == date(2026, 1, 11)

    def test_calendar_month_block(self):
        day = date(2026, 2, 15)
        period = period_for_date(day, interval=3, unit=QuotaPeriodUnit.months)
        assert period.start == date(2026, 1, 1)
        assert period.end == date(2026, 3, 31)

    def test_calendar_year_block(self):
        day = date(2026, 6, 1)
        period = period_for_date(day, interval=2, unit=QuotaPeriodUnit.years)
        assert period.start == date(2025, 1, 1)
        assert period.end == date(2026, 12, 31)
