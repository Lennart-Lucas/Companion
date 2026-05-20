"""Import task modules so handlers register on worker/API startup."""

from app.jobs.tasks import example as example  # noqa: F401
