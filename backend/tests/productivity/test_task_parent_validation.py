import pytest
from pydantic import ValidationError

from app.schemas.task import TaskCreate, TaskUpdate


class TestTaskCreateParentValidation:
    def test_no_parent(self):
        task = TaskCreate(name="Standalone")
        assert task.project_id is None
        assert task.goal_id is None

    def test_project_parent(self):
        task = TaskCreate(name="In project", project_id=1)
        assert task.project_id == 1
        assert task.goal_id is None

    def test_goal_parent(self):
        task = TaskCreate(name="In goal", goal_id=2)
        assert task.goal_id == 2
        assert task.project_id is None

    def test_both_parents_rejected(self):
        with pytest.raises(ValidationError) as exc:
            TaskCreate(name="Invalid", project_id=1, goal_id=2)
        assert "both project_id and goal_id" in str(exc.value).lower()


class TestTaskUpdateParentValidation:
    def test_both_parents_rejected(self):
        with pytest.raises(ValidationError):
            TaskUpdate(project_id=1, goal_id=2)

    def test_clear_to_single_parent(self):
        task = TaskUpdate(project_id=3, goal_id=None)
        assert task.project_id == 3
        assert task.goal_id is None
