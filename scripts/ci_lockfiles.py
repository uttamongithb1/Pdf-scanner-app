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
import zlib

ALLOWED = {"pubspec.lock", "ios/Podfile.lock"}
TITLE = "Public dependency lock"


def gh(*args):
    return json.loads(subprocess.check_output(["gh", *args], text=True))


def emit(name):
    if name not in ALLOWED:
        raise ValueError("Only public dependency lockfiles may be published")
    data = Path(name).read_bytes()
    if not data or len(data) > 256 * 1024:
        raise ValueError("Unexpected lockfile size")
    # Check annotations returned by GitHub's API truncate messages at 4096 bytes.
    encoded = base64.b64encode(zlib.compress(data, 9)).decode("ascii")
    parts = [encoded[i:i + 3000] for i in range(0, len(encoded), 3000)]
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
        page_number = 1
        while True:
            page = gh("api", f"repos/{repo}/check-runs/{job['databaseId']}/annotations"
                      f"?per_page=100&page={page_number}")
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
            if len(page) < 100:
                break
            page_number += 1
    if not locks:
        raise ValueError("No public lockfile annotations found in this run")
    for name, (digest, count, parts) in locks.items():
        if len(parts) != count:
            raise ValueError(f"Incomplete lockfile: {name}")
        compressed = base64.b64decode("".join(parts[i] for i in range(count)), validate=True)
        inflater = zlib.decompressobj()
        data = inflater.decompress(compressed, 256 * 1024 + 1)
        if not inflater.eof or inflater.unused_data or not 0 < len(data) <= 256 * 1024:
            raise ValueError(f"Invalid compressed lockfile: {name}")
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
