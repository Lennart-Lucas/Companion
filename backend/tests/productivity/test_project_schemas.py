from datetime import datetime
from zoneinfo import ZoneInfo

from app.models.project import ProjectStatus
from app.schemas.project import ProjectCreate, ProjectUpdate


class TestProjectSchemas:
    def test_status_default(self):
        project = ProjectCreate(name="New initiative")
        assert project.status == ProjectStatus.planning

    def test_start_date_optional(self):
        start = datetime(2026, 6, 1, 9, 0, tzinfo=ZoneInfo("UTC"))
        project = ProjectCreate(name="Dated", start_date=start, status="active")
        assert project.start_date == start
        assert project.status == ProjectStatus.active

    def test_update_status(self):
        update = ProjectUpdate(status=ProjectStatus.on_hold)
        assert update.status == ProjectStatus.on_hold
