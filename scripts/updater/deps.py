"""Dependency hash calculation (cargoHash, vendorHash, npmDepsHash, ...).

The hash is a function of ``(source, nixpkgs, builder)``, not of the upstream
purl, so it lives in the Nix adapter *above* the fetcher. It is computed with
the dummy-hash-and-build pattern: stage a placeholder, build, and read the
correct hash out of the resulting mismatch error.

:class:`DepHasher` talks to a :class:`~updater.store.StateStore` for the
staging round-trip, so the calculation is decoupled from ``hashes.json`` and
works against any store (inline-nix, nix-update delegate, ...). The build
command is injected so the logic is testable without invoking Nix.
"""

from __future__ import annotations

from typing import TYPE_CHECKING, Any

from .hash import DUMMY_SHA256_HASH, extract_hash_from_build_error
from .nix import NixCommandError, nix_build
from .store import HashesJsonStore

if TYPE_CHECKING:
    from collections.abc import Callable
    from pathlib import Path

    from .store import StateStore


class DepHasher:
    """Compute a dependency hash via the dummy-build error, over a StateStore."""

    def __init__(
        self,
        store: StateStore,
        package_attr: str,
        *,
        build: Callable[..., Any] = nix_build,
    ) -> None:
        """Bind the hasher to a store, a package attr, and a build command."""
        self._store = store
        self._attr = package_attr
        self._build = build

    def hash(self, hash_key: str) -> str:
        """Stage a dummy hash, build, and return the real hash from the error.

        On any failure the store is rolled back to its original value so a
        broken run never leaves a placeholder behind.
        """
        original = self._store.get(hash_key)
        self._store.stage_dummy(hash_key, DUMMY_SHA256_HASH)
        try:
            self._build(self._attr, check=True)
        except NixCommandError as exc:
            found = extract_hash_from_build_error(exc.args[0])
            if not found:
                self._store.rollback(hash_key, original)
                msg = f"Could not extract hash from build error:\n{exc.args[0]}"
                raise ValueError(msg) from exc
            self._store.commit(hash_key, found)
            return found
        # A build with the dummy hash must fail; success means something is off.
        self._store.rollback(hash_key, original)
        msg = "Build succeeded with dummy hash - unexpected"
        raise ValueError(msg)


def update_dependency_hash(
    package_attr: str,
    hash_key: str,
    hashes_file: Path,
    data: dict[str, Any],
) -> None:
    """Calculate a dependency hash and persist it to the hashes file.

    Fails the same way every updater does: on error the process exits
    non-zero, which stops CI from committing a placeholder hash and opening a
    broken update PR.
    """
    store = HashesJsonStore(hashes_file, data=data)
    try:
        DepHasher(store, package_attr).hash(hash_key)
    except (ValueError, NixCommandError) as exc:
        msg = f"Error calculating {hash_key} for {package_attr}: {exc}"
        raise SystemExit(msg) from exc
