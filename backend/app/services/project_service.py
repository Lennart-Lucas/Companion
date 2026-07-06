from fastapi import HTTPException, status
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.project import Project
from app.models.user import User
from app.schemas.project import ProjectCreate, ProjectUpdate
from app.services.productivity_helpers import (
    apply_list_filters,
    assert_goal_owned,
    clamp_pagination,
    soft_delete,
)


async def get_project(
    session: AsyncSession, user: User, project_id: int
) -> Project:
    result = await session.execute(
        select(Project).where(
            Project.id == project_id,
            Project.user_id == user.id,
            Project.deleted_at.is_(None),
        )
    )
    project = result.scalar_one_or_none()
    if project is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Project not found",
        )
    return project


async def create_project(
    session: AsyncSession, user: User, data: ProjectCreate
) -> Project:
    await assert_goal_owned(session, data.goal_id, user.id)
    project = Project(
        user_id=user.id,
        name=data.name,
        start_date=data.start_date,
        deadline=data.deadline,
        description=data.description,
        icon=data.icon,
        color=data.color,
        goal_id=data.goal_id,
        status=data.status.value,
    )
    session.add(project)
    await session.flush()
    return project


async def list_projects(
    session: AsyncSession,
    user: User,
    *,
    limit: int = 50,
    offset: int = 0,
    updated_since=None,
) -> tuple[list[Project], int]:
    limit, offset = clamp_pagination(limit, offset)
    base = select(Project).where(Project.user_id == user.id)
    base = apply_list_filters(base, Project, updated_since=updated_since)
    count_stmt = select(func.count()).select_from(Project).where(
        Project.user_id == user.id
    )
    count_stmt = apply_list_filters(count_stmt, Project, updated_since=updated_since)
    total = (await session.execute(count_stmt)).scalar_one()
    result = await session.execute(
        base.order_by(Project.id).limit(limit).offset(offset)
    )
    return list(result.scalars().all()), total


async def update_project(
    session: AsyncSession, user: User, project_id: int, data: ProjectUpdate
) -> Project:
    project = await get_project(session, user, project_id)
    updates = data.model_dump(exclude_unset=True)
    if "goal_id" in updates:
        await assert_goal_owned(session, updates["goal_id"], user.id)
    for key, value in updates.items():
        if hasattr(value, "value"):
            setattr(project, key, value.value)
        else:
            setattr(project, key, value)
    await session.flush()
    # Server-side onupdate=now() expires updated_at; refresh before response
    # serialization to avoid async lazy-load (MissingGreenlet) errors.
    await session.refresh(project)
    return project


async def delete_project(
    session: AsyncSession, user: User, project_id: int
) -> None:
    project = await get_project(session, user, project_id)
    await soft_delete(project)
