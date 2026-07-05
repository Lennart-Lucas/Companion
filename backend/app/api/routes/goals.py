from datetime import datetime

from fastapi import APIRouter, Depends, Query
from sqlalchemy.ext.asyncio import AsyncSession

from app.dependencies import get_current_active_user, get_db
from app.models.user import User
from app.schemas.goal import GoalCreate, GoalListResponse, GoalResponse, GoalUpdate
from app.schemas.goal_check_in import (
    GoalCheckInListResponse,
    GoalCheckInResponse,
    GoalCheckInUpdate,
)
from app.schemas.goal_milestone import (
    MilestoneCreate,
    MilestoneResponse,
    MilestoneUpdate,
    MilestonesReplace,
)
from app.services import goal_check_in_service, goal_milestone_service, goal_service

router = APIRouter(prefix="/goals", tags=["goals"])


@router.post("", response_model=GoalResponse, status_code=201)
async def create_goal(
    body: GoalCreate,
    session: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_active_user),
) -> GoalResponse:
    goal = await goal_service.create_goal(session, user, body)
    return GoalResponse.model_validate(goal)


@router.get("", response_model=GoalListResponse)
async def list_goals(
    limit: int = Query(default=50, ge=1, le=100),
    offset: int = Query(default=0, ge=0),
    session: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_active_user),
) -> GoalListResponse:
    items, total = await goal_service.list_goals(
        session, user, limit=limit, offset=offset
    )
    return GoalListResponse(
        items=[GoalResponse.model_validate(g) for g in items],
        total=total,
        limit=limit,
        offset=offset,
    )


@router.get("/{goal_id}", response_model=GoalResponse)
async def get_goal(
    goal_id: int,
    session: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_active_user),
) -> GoalResponse:
    goal = await goal_service.get_goal(session, user, goal_id)
    return GoalResponse.model_validate(goal)


@router.patch("/{goal_id}", response_model=GoalResponse)
async def update_goal(
    goal_id: int,
    body: GoalUpdate,
    session: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_active_user),
) -> GoalResponse:
    goal = await goal_service.update_goal(session, user, goal_id, body)
    return GoalResponse.model_validate(goal)


@router.delete("/{goal_id}", status_code=204)
async def delete_goal(
    goal_id: int,
    session: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_active_user),
) -> None:
    await goal_service.delete_goal(session, user, goal_id)


@router.get("/{goal_id}/check-ins", response_model=GoalCheckInListResponse)
async def list_goal_check_ins(
    goal_id: int,
    from_: datetime = Query(alias="from"),
    to: datetime = Query(),
    max_count: int = Query(default=500, ge=1, le=5000),
    session: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_active_user),
) -> GoalCheckInListResponse:
    items = await goal_check_in_service.list_check_ins(
        session, user, goal_id, start=from_, end=to, max_count=max_count
    )
    return GoalCheckInListResponse(items=items)


@router.patch(
    "/{goal_id}/check-ins/{check_in_id}",
    response_model=GoalCheckInResponse,
)
async def update_goal_check_in(
    goal_id: int,
    check_in_id: int,
    body: GoalCheckInUpdate,
    session: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_active_user),
) -> GoalCheckInResponse:
    return await goal_check_in_service.update_check_in(
        session, user, goal_id, check_in_id, body
    )


@router.get("/{goal_id}/milestones", response_model=list[MilestoneResponse])
async def list_goal_milestones(
    goal_id: int,
    session: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_active_user),
) -> list[MilestoneResponse]:
    return await goal_milestone_service.list_milestones(session, user, goal_id)


@router.put("/{goal_id}/milestones", response_model=list[MilestoneResponse])
async def replace_goal_milestones(
    goal_id: int,
    body: MilestonesReplace,
    session: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_active_user),
) -> list[MilestoneResponse]:
    milestones = await goal_milestone_service.replace_milestones(
        session, user, goal_id, body
    )
    return [MilestoneResponse.model_validate(m) for m in milestones]


@router.post(
    "/{goal_id}/milestones",
    response_model=MilestoneResponse,
    status_code=201,
)
async def add_goal_milestone(
    goal_id: int,
    body: MilestoneCreate,
    session: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_active_user),
) -> MilestoneResponse:
    milestone = await goal_milestone_service.add_milestone(
        session, user, goal_id, body
    )
    return MilestoneResponse.model_validate(milestone)


@router.patch(
    "/{goal_id}/milestones/{milestone_id}",
    response_model=MilestoneResponse,
)
async def update_goal_milestone(
    goal_id: int,
    milestone_id: int,
    body: MilestoneUpdate,
    session: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_active_user),
) -> MilestoneResponse:
    milestone = await goal_milestone_service.update_milestone(
        session, user, goal_id, milestone_id, body
    )
    return MilestoneResponse.model_validate(milestone)


@router.delete("/{goal_id}/milestones/{milestone_id}", status_code=204)
async def delete_goal_milestone(
    goal_id: int,
    milestone_id: int,
    session: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_active_user),
) -> None:
    await goal_milestone_service.delete_milestone(session, user, goal_id, milestone_id)
