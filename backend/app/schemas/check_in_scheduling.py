"""Shared validation for quota check-in scheduling."""

from typing import Self

from pydantic import model_validator

from app.models.check_in_scheduling import CheckInMode, QuotaPeriodUnit


def validate_quota_fields(
    *,
    check_in_mode: CheckInMode | str,
    quota_times: int | None,
    quota_period_interval: int | None,
    quota_period_unit: QuotaPeriodUnit | str | None,
) -> None:
    mode = (
        check_in_mode
        if isinstance(check_in_mode, CheckInMode)
        else CheckInMode(check_in_mode)
    )
    if mode != CheckInMode.times_per_period:
        if any(v is not None for v in (quota_times, quota_period_interval, quota_period_unit)):
            raise ValueError(
                "quota fields are only valid when check_in_mode is times_per_period"
            )
        return

    if quota_times is None or quota_times < 1:
        raise ValueError("quota_times must be >= 1 for times_per_period mode")
    if quota_period_interval is None or quota_period_interval < 1:
        raise ValueError("quota_period_interval must be >= 1 for times_per_period mode")
    if quota_period_unit is None:
        raise ValueError("quota_period_unit is required for times_per_period mode")


class QuotaFieldsMixin:
    check_in_mode: CheckInMode = CheckInMode.fixed_schedule
    quota_times: int | None = None
    quota_period_interval: int | None = None
    quota_period_unit: QuotaPeriodUnit | None = None

    @model_validator(mode="after")
    def validate_quota_mode_fields(self) -> Self:
        validate_quota_fields(
            check_in_mode=self.check_in_mode,
            quota_times=self.quota_times,
            quota_period_interval=self.quota_period_interval,
            quota_period_unit=self.quota_period_unit,
        )
        return self
