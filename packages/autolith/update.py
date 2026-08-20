#!/usr/bin/env nix
#! nix shell --inputs-from .# nixpkgs#python3 --command python3

"""Update Autolith's source and Nix build definition."""

import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent.parent.parent / "scripts"))

from updater import (
    calculate_url_hash,
    fetch_github_latest_release,
    fetch_text,
    should_update,
)

PACKAGE_DIR = Path(__file__).parent
SOURCE_NIX = PACKAGE_DIR / "source.nix"
UPSTREAM_PACKAGE_NIX = PACKAGE_DIR / "upstream-package.nix"
OWNER = "lambda-symbolics"
REPO = "autolith"


def _current_version() -> str:
    match = re.search(r'version\s*=\s*"([^"]+)"', SOURCE_NIX.read_text())
    if not match:
        message = "Could not find Autolith version in source.nix"
        raise ValueError(message)
    return match.group(1)


def _source_nix(version: str, hash_value: str) -> str:
    return f"""{{ fetchFromGitHub }}:

let
  version = "{version}";
in
{{
  inherit version;

  src = fetchFromGitHub {{
    owner = "{OWNER}";
    repo = "{REPO}";
    tag = "v${{version}}";
    hash = "{hash_value}";
  }};
}}
"""


def _normalize_package(package: str, fff_source_commit: str) -> str:
    package, count = re.subn(
        r"  expectedSbclVersion = .*?\n  expectedSbclSourceHash = .*?\n",
        "",
        package,
    )
    if count != 1:
        message = "Could not remove Autolith's SBCL version pin"
        raise ValueError(message)

    package, count = re.subn(
        r"  fffSourceCommit = .*?\n",
        f'  fffSourceCommit = "{fff_source_commit}";\n',
        package,
    )
    if count != 1:
        message = "Could not inline Autolith's fff source commit"
        raise ValueError(message)

    replacement = """  sbclSource = pkgs.runCommand "autolith-sbcl-${pkgs.sbcl.version}-source" {
    nativeBuildInputs = [ pkgs.bzip2 pkgs.coreutils pkgs.gnutar ];
  } ''
    mkdir -p "$out"
    tar -xjf ${pkgs.sbcl.src} --strip-components=1 -C "$out"
    test -f "$out/version.lisp-expr"
    test -f "$out/src/code/list.lisp"
  '';

  # Sandboxing"""
    package, count = re.subn(
        r'  sbclSource = pkgs\.runCommand "autolith-sbcl-\$\{expectedSbclVersion\}-source" \{.*?\n  \'\';\n\n  # Sandboxing',
        replacement,
        package,
        flags=re.DOTALL,
    )
    if count != 1:
        message = "Could not relax Autolith's SBCL source check"
        raise ValueError(message)

    package = package.replace(
        '"autolith-image-validation-${expectedSbclVersion}"',
        '"autolith-image-validation-${pkgs.sbcl.version}"',
    )
    package = package.replace("assert pkgs.sbcl.version == expectedSbclVersion;\n", "")
    if "expectedSbcl" in package:
        message = "Autolith's SBCL pin was not fully removed"
        raise ValueError(message)
    return package


def main() -> None:
    """Update Autolith to the latest tagged release."""
    current = _current_version()
    latest = fetch_github_latest_release(OWNER, REPO)
    print(f"Current: {current}, Latest: {latest}")
    if not should_update(current, latest):
        print("Already up to date")
        return

    tag = f"v{latest}"
    base_url = f"https://raw.githubusercontent.com/{OWNER}/{REPO}/{tag}"
    print("Fetching upstream Nix package...")
    upstream_package = fetch_text(f"{base_url}/nix/package.nix")
    fff_source_commit = fetch_text(f"{base_url}/native/fff/commit").strip()
    upstream_package = _normalize_package(upstream_package, fff_source_commit)

    print("Calculating source hash...")
    source_hash = calculate_url_hash(
        f"https://github.com/{OWNER}/{REPO}/archive/refs/tags/{tag}.tar.gz",
        unpack=True,
    )

    SOURCE_NIX.write_text(_source_nix(latest, source_hash))
    UPSTREAM_PACKAGE_NIX.write_text(upstream_package)
    print(f"Updated to {latest}")


if __name__ == "__main__":
    main()
