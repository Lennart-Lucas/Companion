"""Run the async job worker. Usage: python scripts/run_worker.py"""

import asyncio
import os
import sys
from pathlib import Path

os.environ.setdefault("WORKER_PROCESS", "1")

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from app.jobs.worker import run_worker_loop


def main() -> None:
    asyncio.run(run_worker_loop())


if __name__ == "__main__":
    main()
