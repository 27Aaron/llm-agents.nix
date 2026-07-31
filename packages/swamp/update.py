#!/usr/bin/env nix
#! nix shell --inputs-from .# nixpkgs#python3 --command python3

"""Update the Swamp package from the project's official artifact service."""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent.parent.parent / "scripts"))

from updater import (
    calculate_url_hash,
    fetch_json,
    load_hashes,
    save_hashes,
    should_update,
)

HASHES_FILE = Path(__file__).parent / "hashes.json"
TAGS_API = "https://git.swamp-club.com/api/v1/repos/swamp-club/swamp/tags?limit=50"
ARTIFACT_BASE = "https://artifacts.swamp-club.com/swamp"
PLATFORMS = {
    "x86_64-linux": ("linux", "x86_64", "linux-x86_64"),
    "aarch64-linux": ("linux", "aarch64", "linux-aarch64"),
    "aarch64-darwin": ("darwin", "aarch64", "darwin-aarch64"),
}


def latest_version() -> str:
    """Return the newest version from the official repository's tags."""
    tags = fetch_json(TAGS_API)
    if not isinstance(tags, list):
        msg = f"Expected a list of tags, got {type(tags)}"
        raise TypeError(msg)

    versions: list[str] = []
    for tag in tags:
        if not isinstance(tag, dict):
            continue
        name = tag.get("name")
        if isinstance(name, str):
            versions.append(name.removeprefix("v"))
    if not versions:
        msg = "No version tags returned by the official Swamp repository"
        raise ValueError(msg)

    return max(versions)


def artifact_url(version: str, platform: tuple[str, str, str]) -> str:
    """Build an artifact URL using the layout from the official installer."""
    os_name, cpu, artifact = platform
    filename = f"swamp-{version}-binary-{artifact}.tar.gz"
    return f"{ARTIFACT_BASE}/{version}/binary/{os_name}/{cpu}/{filename}"


def main() -> None:
    """Update the version and hashes for all supported platforms."""
    current = load_hashes(HASHES_FILE)["version"]
    latest = latest_version()

    print(f"Current: {current}, Latest: {latest}")
    if not should_update(current, latest):
        print("Already up to date")
        return

    hashes = {}
    for nix_platform, artifact_platform in PLATFORMS.items():
        hashes[nix_platform] = calculate_url_hash(
            artifact_url(latest, artifact_platform)
        )
        print(f"Fetched hash for {nix_platform}")

    save_hashes(HASHES_FILE, {"version": latest, "hashes": hashes})
    print(f"Updated to {latest}")


if __name__ == "__main__":
    main()
