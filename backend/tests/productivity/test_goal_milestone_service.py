from decimal import Decimal

from app.schemas.goal_milestone import MilestoneCreate, MilestonesReplace


def test_milestone_create_defaults():
    milestone = MilestoneCreate(value=Decimal("5"), name="Halfway")
    assert milestone.sort_order == 0


def test_milestones_replace_payload():
    body = MilestonesReplace(
        milestones=[
            MilestoneCreate(value=Decimal("3"), name="A", sort_order=0),
            MilestoneCreate(value=Decimal("7"), sort_order=1),
        ]
    )
    assert len(body.milestones) == 2
    assert body.milestones[1].value == Decimal("7")
