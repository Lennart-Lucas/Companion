from decimal import Decimal

import pytest

from app.models.goal import GoalDirection
from app.schemas.goal_milestone import MilestoneCreate
from app.services.goal_milestone_validation import validate_milestones


def _milestones(*values: str) -> list[MilestoneCreate]:
    return [
        MilestoneCreate(value=Decimal(value), sort_order=index)
        for index, value in enumerate(values)
    ]


class TestValidateMilestones:
    def test_empty_list_is_valid(self):
        validate_milestones(Decimal("12"), GoalDirection.increasing, [])

    def test_valid_increasing_milestones(self):
        validate_milestones(
            Decimal("12"),
            GoalDirection.increasing,
            _milestones("3", "6", "9"),
        )

    def test_valid_decreasing_milestones(self):
        validate_milestones(
            Decimal("2"),
            GoalDirection.decreasing,
            _milestones("8", "5", "3"),
        )

    def test_rejects_increasing_at_target(self):
        with pytest.raises(ValueError, match="less than target"):
            validate_milestones(
                Decimal("12"),
                GoalDirection.increasing,
                _milestones("6", "12"),
            )

    def test_rejects_increasing_beyond_target(self):
        with pytest.raises(ValueError, match="less than target"):
            validate_milestones(
                Decimal("12"),
                GoalDirection.increasing,
                _milestones("15"),
            )

    def test_rejects_decreasing_at_target(self):
        with pytest.raises(ValueError, match="greater than target"):
            validate_milestones(
                Decimal("2"),
                GoalDirection.decreasing,
                _milestones("2"),
            )

    def test_rejects_decreasing_below_target(self):
        with pytest.raises(ValueError, match="greater than target"):
            validate_milestones(
                Decimal("2"),
                GoalDirection.decreasing,
                _milestones("1"),
            )

    def test_rejects_duplicate_values(self):
        with pytest.raises(ValueError, match="unique"):
            validate_milestones(
                Decimal("12"),
                GoalDirection.increasing,
                _milestones("3", "3"),
            )

    def test_rejects_wrong_increasing_order(self):
        with pytest.raises(ValueError, match="ascending"):
            validate_milestones(
                Decimal("12"),
                GoalDirection.increasing,
                _milestones("9", "3"),
            )

    def test_rejects_wrong_decreasing_order(self):
        with pytest.raises(ValueError, match="descending"):
            validate_milestones(
                Decimal("2"),
                GoalDirection.decreasing,
                _milestones("3", "8"),
            )

    def test_rejects_non_positive_increasing_value(self):
        with pytest.raises(ValueError, match="greater than 0"):
            validate_milestones(
                Decimal("12"),
                GoalDirection.increasing,
                _milestones("0"),
            )
