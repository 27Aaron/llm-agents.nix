"""Tests for the declarative updater runner (config -> flow dispatch).

Zero-dependency (stdlib ``unittest``). The flow functions are replaced with
recorders, so run() is verified offline: it maps each purl + kind to the right
flow call with the right arguments.
"""

from __future__ import annotations

import unittest
from pathlib import Path
from typing import Any

from updater.run import run

PKG = Path("packages/example")


class Recorder:
    """A stand-in flow that records the call it received."""

    def __init__(self) -> None:
        self.args: tuple[Any, ...] | None = None
        self.kwargs: dict[str, Any] | None = None

    def __call__(self, *args: Any, **kwargs: Any) -> None:
        self.args = args
        self.kwargs = kwargs


def recorders() -> dict[str, Recorder]:
    return {k: Recorder() for k in ("github-source", "npm", "bun-github")}


class TestRun(unittest.TestCase):
    def test_github_source(self) -> None:
        flows = recorders()
        run(
            PKG,
            {
                "kind": "github-source",
                "purl": "pkg:github/charmbracelet/crush",
                "flakeAttr": ".#crush",
                "depHashKey": "vendorHash",
            },
            flows=flows,  # type: ignore[arg-type]
        )
        rec = flows["github-source"]
        self.assertEqual(
            rec.args, (PKG, "charmbracelet", "crush", ".#crush", "vendorHash")
        )

    def test_bun_github_default_prefix(self) -> None:
        flows = recorders()
        run(
            PKG,
            {"kind": "bun-github", "purl": "pkg:github/gmickel/gno"},
            flows=flows,  # type: ignore[arg-type]
        )
        rec = flows["bun-github"]
        self.assertEqual(rec.args, (PKG, "gmickel", "gno"))
        self.assertEqual(rec.kwargs, {"ref_prefix": "v"})

    def test_bun_github_custom_prefix(self) -> None:
        flows = recorders()
        run(
            PKG,
            {"kind": "bun-github", "purl": "pkg:github/o/r", "refPrefix": "release-"},
            flows=flows,  # type: ignore[arg-type]
        )
        self.assertEqual(flows["bun-github"].kwargs, {"ref_prefix": "release-"})

    def test_npm_scoped(self) -> None:
        flows = recorders()
        run(
            PKG,
            {
                "kind": "npm",
                "purl": "pkg:npm/%40zaly/cli",
                "flakeAttr": ".#zaly",
                "fetchzip": True,
            },
            flows=flows,  # type: ignore[arg-type]
        )
        rec = flows["npm"]
        assert rec.args is not None
        self.assertEqual(rec.args[:3], (PKG, "@zaly/cli", ".#zaly"))
        assert rec.kwargs is not None
        self.assertTrue(rec.kwargs["fetchzip"])
        self.assertTrue(rec.kwargs["require_lockfile"])

    def test_npm_unscoped(self) -> None:
        flows = recorders()
        run(
            PKG,
            {"kind": "npm", "purl": "pkg:npm/skills", "flakeAttr": ".#skills"},
            flows=flows,  # type: ignore[arg-type]
        )
        assert flows["npm"].args is not None
        self.assertEqual(flows["npm"].args[1], "skills")

    def test_unknown_kind_raises(self) -> None:
        with self.assertRaises(ValueError):
            run(PKG, {"kind": "mystery", "purl": "pkg:github/o/r"}, flows=recorders())  # type: ignore[arg-type]

    def test_github_source_needs_owner(self) -> None:
        with self.assertRaises(ValueError):
            run(
                PKG,
                {
                    "kind": "github-source",
                    "purl": "pkg:github/lonerepo",
                    "flakeAttr": ".#x",
                    "depHashKey": "vendorHash",
                },
                flows=recorders(),  # type: ignore[arg-type]
            )


if __name__ == "__main__":
    unittest.main(verbosity=2)
