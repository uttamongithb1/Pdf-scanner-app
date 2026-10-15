#!/usr/bin/env python3
"""Transfer public dependency locks via CI annotations when blob downloads are blocked.

Normal users can download the resolved-packages artifact instead. Never use this
for signing files, credentials, environment dumps, or arbitrary workspace files.
"""
import argparse
import base64
import hashlib
import json
from pathlib import Path
import subprocess

ALLOWED = {"pubspec.lock", "ios/Podfile.lock"}
TITLE = "Public dependency lock"


def gh(*args):
    return json.loads(subprocess.check_output(["gh", *args], text=True))


def emit(name):
    if name not in ALLOWED:
        raise ValueError("Only public dependency lockfiles may be published")
    data = Path(name).read_bytes()
    encoded = base64.b64encode(data).decode("ascii")
    parts = [encoded[i:i + 6000] for i in range(0, len(encoded), 6000)]
    if not parts or len(parts) > 8:
        raise ValueError("Unexpected lockfile size")
    digest = hashlib.sha256(data).hexdigest()
    for index, part in enumerate(parts):
        print(f"::notice title={TITLE}::{name} {digest} {index}/{len(parts)} {part}")


def fetch(run_id):
    run = gh("run", "view", run_id, "--json", "headSha,jobs")
    head = subprocess.check_output(["git", "rev-parse", "HEAD"], text=True).strip()
    if run["headSha"] != head:
        raise ValueError("Check out the CI source commit before importing its lockfiles")
    repo = gh("repo", "view", "--json", "nameWithOwner")["nameWithOwner"]
    locks = {}
    for job in run["jobs"]:
        pages = gh("api", "--paginate", "--slurp",
                   f"repos/{repo}/check-runs/{job['databaseId']}/annotations?per_page=100")
        for page in pages:
            for annotation in page:
                if annotation.get("title") != TITLE:
                    continue
                name, digest, position, part = annotation["message"].split()
                if name not in ALLOWED:
                    raise ValueError("Unexpected output path")
                index, count = map(int, position.split("/"))
                if not 0 <= index < count <= 8:
                    raise ValueError("Invalid chunk count")
                entry = locks.setdefault(name, (digest, count, {}))
                if entry[:2] != (digest, count) or index in entry[2]:
                    raise ValueError("Conflicting lockfile annotations")
                entry[2][index] = part
    if not locks:
        raise ValueError("No public lockfile annotations found in this run")
    for name, (digest, count, parts) in locks.items():
        if len(parts) != count:
            raise ValueError(f"Incomplete lockfile: {name}")
        data = base64.b64decode("".join(parts[i] for i in range(count)), validate=True)
        if hashlib.sha256(data).hexdigest() != digest:
            raise ValueError(f"Checksum mismatch: {name}")
        target = Path(name)
        if target.exists() and target.read_bytes() != data:
            raise ValueError(f"Refusing to overwrite an existing different {name}")
        target.write_bytes(data)
        print(f"Retrieved {name}: {len(data)} bytes, sha256 {digest}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("action", choices=["emit", "fetch"])
    parser.add_argument("value", help="Allowlisted path for emit; GitHub run ID for fetch")
    args = parser.parse_args()
    if args.action == "emit":
        emit(args.value)
    else:
        fetch(args.value)
