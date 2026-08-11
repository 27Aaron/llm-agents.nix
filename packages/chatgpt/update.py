#!/usr/bin/env nix
#! nix shell --inputs-from .# nixpkgs#python3 --command python3
"""Update ChatGPT from OpenAI's moving latest Debian package."""

import base64
import hashlib
import io
import sys
import tarfile
import tempfile
import urllib.request
from pathlib import Path
from typing import BinaryIO

sys.path.insert(0, str(Path(__file__).parent.parent.parent / "scripts"))

from updater import load_hashes, save_hashes, should_update

HASHES_FILE = Path(__file__).parent / "hashes.json"
URL_BASE = "https://persistent.oaistatic.com/codex-app-prod/linux/deb/latest"
PLATFORMS = {
    "aarch64-linux": "chatgpt_arm64.deb",
    "x86_64-linux": "chatgpt_amd64.deb",
}
USER_AGENT = (
    "llm-agents.nix package updater (+https://github.com/numtide/llm-agents.nix)"
)
AR_HEADER_SIZE = 60


def request(url: str, *, method: str = "GET") -> urllib.request.Request:
    """Build a request accepted by OpenAI's CDN."""
    return urllib.request.Request(
        url,
        method=method,
        headers={"User-Agent": USER_AGENT},
    )


def remote_etag(url: str) -> str | None:
    """Return the latest artifact's ETag when the server supplies one."""
    with urllib.request.urlopen(request(url, method="HEAD")) as response:
        etag = response.headers.get("ETag")
        return str(etag) if etag is not None else None


def read_ar_member(archive: BinaryIO, wanted: str) -> bytes:
    """Read one member from the simple ar container used by Debian packages."""
    archive.seek(0)
    if archive.read(8) != b"!<arch>\n":
        msg = "download is not an ar archive"
        raise ValueError(msg)

    while header := archive.read(AR_HEADER_SIZE):
        if len(header) != AR_HEADER_SIZE:
            msg = "truncated ar member header"
            raise ValueError(msg)
        name = header[:16].decode().strip().removesuffix("/")
        size = int(header[48:58].decode().strip())
        if name == wanted:
            return archive.read(size)
        archive.seek(size + size % 2, io.SEEK_CUR)

    msg = f"{wanted} not found in Debian package"
    raise ValueError(msg)


def debian_version(archive: BinaryIO) -> str:
    """Extract Version from the package's Debian control metadata."""
    control_archive = read_ar_member(archive, "control.tar.xz")
    with tarfile.open(fileobj=io.BytesIO(control_archive), mode="r:xz") as tar:
        control = tar.extractfile("./control")
        if control is None:
            msg = "control file not found in control.tar.xz"
            raise ValueError(msg)
        for line in control.read().decode().splitlines():
            if line.startswith("Version: "):
                return line.removeprefix("Version: ")

    msg = "Version field not found in Debian control file"
    raise ValueError(msg)


def update_source(
    platform: str,
    filename: str,
    current: dict[str, str],
) -> tuple[dict[str, str], bool]:
    """Refresh one platform source if its upstream ETag changed."""
    url = f"{URL_BASE}/{filename}"
    etag = remote_etag(url)
    if etag and etag == current.get("etag"):
        print(f"{platform}: already up to date")
        return current, False

    print(f"{platform}: downloading latest ChatGPT Debian package...")
    with tempfile.TemporaryFile() as download:
        hasher = hashlib.sha256()
        with urllib.request.urlopen(request(url)) as response:
            while chunk := response.read(1024 * 1024):
                download.write(chunk)
                hasher.update(chunk)

        version = debian_version(download)
        if not should_update(current.get("version", ""), version):
            print(
                f"Warning: {platform} artifact changed without a version bump ({version})"
            )

        digest = base64.b64encode(hasher.digest()).decode()
    updated = {
        "version": version,
        "url": url,
        "hash": f"sha256-{digest}",
    }
    if etag:
        updated["etag"] = etag
    print(f"{platform}: updated to {version}")
    return updated, True


def main() -> None:
    """Refresh every pinned platform when OpenAI changes an artifact."""
    current = load_hashes(HASHES_FILE)
    current_sources = current.get("sources", {})
    sources = {}
    changed = False
    for platform, filename in PLATFORMS.items():
        source, source_changed = update_source(
            platform,
            filename,
            current_sources.get(platform, {}),
        )
        sources[platform] = source
        changed = changed or source_changed

    if not changed:
        print("chatgpt: already up to date")
        return

    save_hashes(HASHES_FILE, {"sources": sources})


if __name__ == "__main__":
    main()
