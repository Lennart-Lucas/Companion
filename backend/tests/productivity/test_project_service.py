import pytest
from sqlalchemy import select

from app.database import async_session_factory
from app.models.project import Project
from app.models.user import User
from app.schemas.project import ProjectResponse, ProjectUpdate
from app.services.project_service import update_project


@pytest.mark.asyncio
async def test_update_project_can_be_serialized_for_response():
    async with async_session_factory() as session:
        user = (await session.execute(select(User).limit(1))).scalar_one_or_none()
        if user is None:
            pytest.skip("requires at least one user in the database")

        project = (
            await session.execute(
                select(Project).where(
                    Project.user_id == user.id,
                    Project.deleted_at.is_(None),
                ).limit(1)
            )
        ).scalar_one_or_none()
        if project is None:
            pytest.skip("requires at least one project in the database")

        updated = await update_project(
            session,
            user,
            project.id,
            ProjectUpdate.model_validate(
                {
                    "name": project.name,
                    "status": "active",
                    "start_date": "2026-07-06T22:00:00.000Z",
                }
            ),
        )

        response = ProjectResponse.model_validate(updated)
        assert response.status.value == "active"
        assert response.updated_at is not None

        await session.rollback()
