#!/usr/bin/env nix
#! nix shell --inputs-from .# nixpkgs#python3 nixpkgs#nodejs --command python3
# Copyright (c) 2026 Numtide

"""Update script for the bb-app package."""

import json
import sys
from pathlib import Path
from typing import Any
from urllib.parse import quote

sys.path.insert(0, str(Path(__file__).parent.parent.parent / "scripts"))

from updater import (
    calculate_url_hash,
    extract_or_generate_lockfile,
    fetch_json,
    fetch_npm_version,
    load_hashes,
    should_update,
)
from updater.deps import update_dependency_hash
from updater.hash import DUMMY_SHA256_HASH
from updater.hashes_file import save_hashes

PACKAGE_DIR = Path(__file__).parent
HASHES_FILE = PACKAGE_DIR / "hashes.json"
LOCK_FILE = PACKAGE_DIR / "package-lock.json"


def package_name(package_path: str) -> str | None:
    """Return the package name after the final node_modules segment."""
    marker = "node_modules/"
    if marker not in package_path:
        return None
    return package_path.rsplit(marker, 1)[1]


def enrich_lockfile() -> None:
    """Add integrity metadata omitted from duplicate entries by npm 11."""
    lock: dict[str, Any] = json.loads(LOCK_FILE.read_text())
    packages = lock.get("packages")
    if not isinstance(packages, dict):
        msg = "package-lock.json has no packages object"
        raise TypeError(msg)

    count = 0
    for path, value in packages.items():
        if not isinstance(path, str) or not isinstance(value, dict):
            continue
        name = package_name(path)
        version = value.get("version")
        if (
            name is None
            or not isinstance(version, str)
            or value.get("link") is True
            or "integrity" in value
        ):
            continue

        url = (
            "https://registry.npmjs.org/"
            f"{quote(name, safe='')}/{quote(version, safe='')}"
        )
        metadata = fetch_json(url)
        dist = metadata.get("dist") if isinstance(metadata, dict) else None
        if not isinstance(dist, dict):
            msg = f"Missing npm dist metadata for {name}@{version}"
            raise TypeError(msg)
        tarball = dist.get("tarball")
        integrity = dist.get("integrity")
        if not isinstance(tarball, str) or not isinstance(integrity, str):
            msg = f"Incomplete npm dist metadata for {name}@{version}"
            raise TypeError(msg)
        value.update({"resolved": tarball, "integrity": integrity})
        count += 1

    LOCK_FILE.write_text(json.dumps(lock, indent=2) + "\n")
    print(f"Added registry metadata to {count} lockfile entries")


current_data = load_hashes(HASHES_FILE)
current = current_data["version"]
latest = fetch_npm_version("bb-app")

print(f"Current: {current}, Latest: {latest}")
if not should_update(current, latest):
    print("Already up to date")
    sys.exit(0)

tarball_url = f"https://registry.npmjs.org/bb-app/-/bb-app-{latest}.tgz"
print("Calculating source hash...")
source_hash = calculate_url_hash(tarball_url)

if not extract_or_generate_lockfile(
    tarball_url,
    LOCK_FILE,
    strip_dev_dependencies=True,
):
    sys.exit(1)
enrich_lockfile()

data = {
    "version": latest,
    "sourceHash": source_hash,
    "npmDepsHash": DUMMY_SHA256_HASH,
}
save_hashes(HASHES_FILE, data)

print("Calculating npm dependencies hash...")
update_dependency_hash(".#bb-app", "npmDepsHash", HASHES_FILE, data)
print(f"Updated to {latest}")
