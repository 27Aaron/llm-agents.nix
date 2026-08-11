#!/usr/bin/env nix
#! nix shell --inputs-from .# nixpkgs#python3 --command python3

"""Update script for qoder-cli package (prebuilt binaries from manifest)."""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent.parent.parent / "scripts"))

from updater import update_manifest_binaries

update_manifest_binaries(
    Path(__file__).parent,
    manifest_url="https://qoder-ide.oss-ap-southeast-1.aliyuncs.com/qodercli/channels/manifest.json",
    platform_map={
        ("linux", "amd64"): "x86_64-linux",
        ("linux", "arm64"): "aarch64-linux",
        ("darwin", "arm64"): "aarch64-darwin",
    },
)
