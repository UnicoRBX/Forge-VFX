#!/usr/bin/env python3
"""Run the engine test lane on real Roblox servers via Open Cloud.

Uploads the built place as a *saved* (never published) version, runs
scripts/cloud_entry.luau against that version as a Luau execution session task,
prints the task's logs, and exits non-zero unless the task completed.

Usage:  python3 scripts/roblox_cloud_test.py [place.rbxl] [entry.luau]

Credentials come from ROBLOX_API_KEY, ROBLOX_UNIVERSE_ID and ROBLOX_PLACE_ID,
read from the environment or from a local .env, which is gitignored.
"""

import json
import os
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent

DEFAULT_PLACE = ROOT / ".build" / "test.rbxl"
DEFAULT_ENTRY = ROOT / "scripts" / "cloud_entry.luau"

POLL_SECONDS = 3
POLL_TIMEOUT_SECONDS = 600

# QUEUED and PROCESSING are the two states that mean "keep waiting"; everything
# else is terminal. Treating only PROCESSING as pending would report a freshly
# queued task as a failure.
PENDING_STATES = {"STATE_UNSPECIFIED", "QUEUED", "PROCESSING"}


def load_dotenv(path):
    if not path.exists():
        return

    for line in path.read_text().splitlines():
        line = line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue

        key, value = line.split("=", 1)
        os.environ.setdefault(key.strip(), value.strip())


def require_env(name):
    value = os.environ.get(name)
    if not value:
        sys.exit(f"{name} is not set; see .env.template")
    return value


def request(url, headers, body=None, method=None, retries=3):
    if method is None:
        method = "GET" if body is None else "POST"

    for attempt in range(retries):
        req = urllib.request.Request(url, data=body, headers=headers, method=method)
        try:
            with urllib.request.urlopen(req) as response:
                return json.loads(response.read())
        except urllib.error.HTTPError as error:
            detail = error.read().decode("utf8", "replace")
            # 4xx is a bad request or a bad key: retrying cannot change it.
            if error.code < 500 or attempt == retries - 1:
                sys.exit(f"{method} {url} failed with {error.code}:\n{detail}")
            print(f"retrying {error.code}", file=sys.stderr)
        except urllib.error.URLError as error:
            if attempt == retries - 1:
                raise
            print(f"retrying {error.reason}", file=sys.stderr)

        time.sleep(1)


def upload_place(api_key, universe, place, place_file):
    """Save a new place version and return its version number.

    versionType=Saved, not Published: the engine lane must never change what a
    player would load, and a task can target a saved version directly.
    """
    url = (
        f"https://apis.roblox.com/universes/v1/{universe}"
        f"/places/{place}/versions?versionType=Saved"
    )
    headers = {
        "x-api-key": api_key,
        "Content-Type": "application/octet-stream",
    }

    result = request(url, headers, body=place_file.read_bytes())
    return result["versionNumber"]


def create_task(api_key, universe, place, version, source):
    url = (
        f"https://apis.roblox.com/cloud/v2/universes/{universe}"
        f"/places/{place}/versions/{version}/luau-execution-session-tasks"
    )
    headers = {"x-api-key": api_key, "Content-Type": "application/json"}

    return request(url, headers, body=json.dumps({"script": source}).encode("utf8"))


def poll_task(api_key, path):
    url = f"https://apis.roblox.com/cloud/v2/{path}"
    headers = {"x-api-key": api_key}
    deadline = time.monotonic() + POLL_TIMEOUT_SECONDS

    while True:
        task = request(url, headers)

        if task["state"] not in PENDING_STATES:
            sys.stderr.write("\n")
            return task

        if time.monotonic() > deadline:
            sys.exit(f"\ntask still {task['state']} after {POLL_TIMEOUT_SECONDS}s")

        sys.stderr.write(".")
        sys.stderr.flush()
        time.sleep(POLL_SECONDS)


def print_logs(api_key, path):
    url = f"https://apis.roblox.com/cloud/v2/{path}/logs"
    logs = request(url, {"x-api-key": api_key})

    for page in logs.get("luauExecutionSessionTaskLogs", []):
        for message in page.get("messages", []):
            print(message)


def main():
    load_dotenv(ROOT / ".env")

    api_key = require_env("ROBLOX_API_KEY")
    universe = require_env("ROBLOX_UNIVERSE_ID")
    place = require_env("ROBLOX_PLACE_ID")

    place_file = Path(sys.argv[1]) if len(sys.argv) > 1 else DEFAULT_PLACE
    entry_file = Path(sys.argv[2]) if len(sys.argv) > 2 else DEFAULT_ENTRY

    if not place_file.exists():
        sys.exit(f"{place_file} does not exist; run scripts/build-test-place.sh")

    print(f"uploading {place_file.name} ({place_file.stat().st_size} bytes)")
    version = upload_place(api_key, universe, place, place_file)

    print(f"running {entry_file.name} against place version {version}")
    task = create_task(
        api_key, universe, place, version, entry_file.read_text(encoding="utf8")
    )

    task = poll_task(api_key, task["path"])
    print_logs(api_key, task["path"])

    if task["state"] == "COMPLETE":
        print("engine lane passed")
        return 0

    error = task.get("error", {})
    print(
        f"engine lane failed: {task['state']} "
        f"{error.get('code', '')} {error.get('message', '')}".strip(),
        file=sys.stderr,
    )
    return 1


if __name__ == "__main__":
    sys.exit(main())
