"""Interpolate ``{name}`` placeholders in a URL template.

This MUST match Nix ``builtins.replaceStrings`` (see lib/interpolate.nix)
exactly, because the build interpolates a URL with the Nix version and the
updater interpolates the same template here — any divergence means the two
fetch different URLs. The shared contract is exercised by the
``interpolate-conformance`` flake check over scripts/updater/interpolate_cases.json.

Semantics (matching replaceStrings, NOT str.format):
- Replace each ``{name}`` for name in ``variables``; a single left-to-right
  pass, so text introduced by a replacement is not re-scanned.
- Placeholders with no matching variable are left as-is (no error).
- Extra variables are unused; a literal ``{`` or ``}`` is fine.
"""

from __future__ import annotations

import re


def interpolate(template: str, variables: dict[str, str]) -> str:
    """Replace ``{name}`` with ``variables[name]`` in one pass."""
    if not variables:
        return template
    pattern = re.compile("|".join(re.escape("{" + name + "}") for name in variables))
    return pattern.sub(lambda m: variables[m.group(0)[1:-1]], template)
