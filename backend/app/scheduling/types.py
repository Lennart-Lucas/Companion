from dataclasses import dataclass, field
from datetime import date, datetime
from enum import Enum


class OverrideScope(str, Enum):
    from_date = "from_date"
    single_occurrence = "single_occurrence"


@dataclass
class ScheduleOverrideData:
    scope: OverrideScope
    effective_at: datetime
    replacement: "ScheduleBundle"


@dataclass
class ScheduleBundle:
    dtstart: datetime
    timezone: str
    rrule: str | None = None
    rdates: list[date] = field(default_factory=list)
    exclusions: set[date] = field(default_factory=set)
    overrides: list[ScheduleOverrideData] = field(default_factory=list)
    schedule_id: int | None = None
