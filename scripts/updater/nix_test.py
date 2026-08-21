"""Tests for Nix updater command construction."""

from __future__ import annotations

import unittest
from unittest.mock import patch

from updater.nix import nix_build


class TestNixBuild(unittest.TestCase):
    def test_suppresses_result_link(self) -> None:
        with patch("updater.nix.nix_command") as nix_command:
            nix_build(".#package")

        nix_command.assert_called_once_with(
            ["build", "--no-link", "--log-format", "bar-with-logs", ".#package"],
            check=True,
        )


if __name__ == "__main__":
    unittest.main(verbosity=2)
