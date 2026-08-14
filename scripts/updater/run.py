"""Declarative updater runner: execute a package's ``passthru.updater`` config.

Instead of a hand-written ``packages/<name>/update.py``, a package can declare
its update recipe as data on the derivation::

    passthru.updater = {
      kind = "github-source";              # which flow to run
      purl = "pkg:github/charmbracelet/crush";
      flakeAttr = ".#crush";
      depHashKey = "vendorHash";
    };

``mkUpdateScript`` serializes that attrset to JSON (Nix does the eval) and calls
this runner. The runner turns the purl back into the flow's arguments and
delegates to the existing, tested flow functions — so declarative packages and
legacy ``update.py`` scripts share one code path.

Only the cleanly-derivable kinds live here (``github-source``, ``npm``,
``bun-github``): their version and source URL follow from the purl alone.
Packages with bespoke version discovery keep an imperative ``update.py``.
"""

from __future__ import annotations

import argparse
import json
from collections.abc import Callable
from pathlib import Path
from typing import Any

from .flows import update_bun_github, update_github_source, update_npm_package
from .purl import Purl

# The flow entry points, injectable so run() is testable without network/Nix.
FlowMap = dict[str, Callable[..., None]]

_DEFAULT_FLOWS: FlowMap = {
    "github-source": update_github_source,
    "npm": update_npm_package,
    "bun-github": update_bun_github,
}


def _owner(purl: Purl) -> str:
    """Return the purl's namespace (repo owner), or raise if absent."""
    if purl.namespace is None:
        msg = f"purl {purl} needs an owner (namespace)"
        raise ValueError(msg)
    return purl.namespace


def run(pkg_dir: Path, config: dict[str, Any], *, flows: FlowMap | None = None) -> None:
    """Execute one declarative updater config against ``pkg_dir``."""
    flow = flows if flows is not None else _DEFAULT_FLOWS
    kind = config["kind"]
    purl = Purl.parse(config["purl"])

    if kind == "github-source":
        flow["github-source"](
            pkg_dir,
            _owner(purl),
            purl.name,
            config["flakeAttr"],
            config["depHashKey"],
        )
    elif kind == "bun-github":
        flow["bun-github"](
            pkg_dir,
            _owner(purl),
            purl.name,
            ref_prefix=config.get("refPrefix", "v"),
        )
    elif kind == "npm":
        package = f"{purl.namespace}/{purl.name}" if purl.namespace else purl.name
        flow["npm"](
            pkg_dir,
            package,
            config["flakeAttr"],
            fetchzip=config.get("fetchzip", False),
            require_lockfile=config.get("requireLockfile", True),
            strip_dev_dependencies=config.get("stripDevDependencies", False),
            supplement_optional_deps=config.get("supplementOptionalDeps", False),
            lockfile_env=config.get("lockfileEnv"),
        )
    else:
        msg = f"unknown updater kind {kind!r}"
        raise ValueError(msg)


def main(argv: list[str] | None = None) -> None:
    """CLI entry: ``python3 -m updater.run --pkg-dir DIR --config JSON``."""
    parser = argparse.ArgumentParser(description="Run a passthru.updater config.")
    parser.add_argument("--pkg-dir", required=True, type=Path)
    parser.add_argument("--config", required=True, help="updater config as JSON")
    args = parser.parse_args(argv)

    pkg_dir: Path = args.pkg_dir
    config_json: str = args.config
    config: dict[str, Any] = json.loads(config_json)
    run(pkg_dir, config)


if __name__ == "__main__":
    main()
