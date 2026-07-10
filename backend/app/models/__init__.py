"""Import all model modules here so Alembic autogenerate discovers them."""

from app.models.async_job import AsyncJob
from app.models.async_job_error import AsyncJobError
from app.models.base import Base
from app.models.device import Device
from app.models.event import Event
from app.models.encrypted_message import EncryptedMessage
from app.models.goal import Goal, GoalDirection, GoalType
from app.models.goal_check_in import GoalCheckIn
from app.models.goal_milestone import GoalMilestone
from app.models.identity_key import IdentityKey
from app.models.media_title import MediaTitle
from app.models.onetime_prekey import OneTimePreKey
from app.models.project import Project, ProjectStatus
from app.models.refresh_token import RefreshToken
from app.models.schedule import Schedule
from app.models.schedule_exclusion import ScheduleExclusion
from app.models.schedule_override import ScheduleOverride
from app.models.schedule_specific_date import ScheduleSpecificDate
from app.models.signed_prekey import SignedPreKey
from app.models.task import Task, TaskPriority, TaskStatus
from app.models.task_occurrence import TaskOccurrence
from app.models.task_occurrence_subtask import TaskOccurrenceSubtask
from app.models.task_subtask import TaskSubtask
from app.models.tracker import CheckInType, HabitDirection, Tracker
from app.models.tracker_check_in import TrackerCheckIn
from app.models.user import User

__all__ = [
    "AsyncJob",
    "AsyncJobError",
    "Base",
    "Device",
    "EncryptedMessage",
    "Event",
    "Goal",
    "GoalCheckIn",
    "GoalDirection",
    "GoalMilestone",
    "GoalType",
    "MediaTitle",
    "IdentityKey",
    "OneTimePreKey",
    "Project",
    "ProjectStatus",
    "RefreshToken",
    "Schedule",
    "ScheduleExclusion",
    "ScheduleOverride",
    "ScheduleSpecificDate",
    "SignedPreKey",
    "Task",
    "TaskOccurrence",
    "TaskOccurrenceSubtask",
    "TaskPriority",
    "TaskStatus",
    "TaskSubtask",
    "CheckInType",
    "HabitDirection",
    "Tracker",
    "TrackerCheckIn",
    "User",
]
