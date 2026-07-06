import enum


class CheckInMode(str, enum.Enum):
    fixed_schedule = "fixed_schedule"
    times_per_period = "times_per_period"


class QuotaPeriodUnit(str, enum.Enum):
    weeks = "weeks"
    months = "months"
    years = "years"


class SlotKind(str, enum.Enum):
    active = "active"
    locked = "locked"
    period_miss = "period_miss"
