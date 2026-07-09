from decimal import Decimal

from app.models.goal import GoalDirection
from app.schemas.goal_milestone import MilestoneCreate


def validate_milestones(
    target: Decimal,
    direction: GoalDirection | str,
    milestones: list[MilestoneCreate],
) -> None:
    """Ensure milestone values sit between start and target (direction-aware)."""
    if not milestones:
        return

    dir_value = direction.value if isinstance(direction, GoalDirection) else direction

    ordered = sorted(
        enumerate(milestones),
        key=lambda pair: pair[1].sort_order if pair[1].sort_order else pair[0],
    )
    values = [item.value for _, item in ordered]

    if len(values) != len(set(values)):
        raise ValueError("Milestone values must be unique")

    for value in values:
        if dir_value == GoalDirection.increasing.value:
            if value <= 0:
                raise ValueError("Milestone value must be greater than 0")
            if value >= target:
                raise ValueError(
                    "Milestone value must be less than target for increasing goals"
                )
        elif value <= target:
            raise ValueError(
                "Milestone value must be greater than target for decreasing goals"
            )

    if dir_value == GoalDirection.increasing.value:
        if values != sorted(values):
            raise ValueError(
                "Milestones must be in ascending order for increasing goals"
            )
    elif values != sorted(values, reverse=True):
        raise ValueError(
            "Milestones must be in descending order for decreasing goals"
        )
