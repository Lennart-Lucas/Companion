from collections.abc import Awaitable, Callable
from typing import Any

from sqlalchemy.ext.asyncio import AsyncSession

TaskHandler = Callable[[AsyncSession, dict[str, Any]], Awaitable[None]]

_REGISTRY: dict[str, TaskHandler] = {}


def register_task(name: str) -> Callable[[TaskHandler], TaskHandler]:
    def decorator(handler: TaskHandler) -> TaskHandler:
        if name in _REGISTRY:
            raise ValueError(f"Task {name!r} is already registered")
        _REGISTRY[name] = handler
        return handler

    return decorator


def get_task(name: str) -> TaskHandler | None:
    return _REGISTRY.get(name)


def registered_task_names() -> list[str]:
    return sorted(_REGISTRY.keys())
