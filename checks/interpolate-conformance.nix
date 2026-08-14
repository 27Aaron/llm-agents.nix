# Prove the Nix and Python URL-template interpolation implement identical logic.
#
# The build interpolates a package's URL with lib/interpolate.nix; the updater
# interpolates the same template with scripts/updater/interpolate.py. If they
# ever diverge, the build and the updater would fetch different URLs. This check
# runs BOTH over one shared fixture (scripts/updater/interpolate_cases.json) and
# fails unless every case agrees — Nix result == Python result == expected.
{
  pkgs,
  flake,
}:
let
  interpolate = import ../lib/interpolate.nix;
  casesJson = builtins.readFile ../scripts/updater/interpolate_cases.json;
  cases = builtins.fromJSON casesJson;
  # Compute every case with the Nix implementation at eval time.
  nixResults = map (case: interpolate case.template case.vars) cases;
in
pkgs.runCommand "interpolate-conformance"
  {
    nativeBuildInputs = [ pkgs.python3 ];
    nixResultsJson = builtins.toJSON nixResults;
    inherit casesJson;
  }
  ''
    cp -r ${flake}/scripts scripts
    export PYTHONPATH="$PWD/scripts"
    printf '%s' "$casesJson" > cases.json
    printf '%s' "$nixResultsJson" > nix.json
    python3 - <<'PY'
    import json
    from pathlib import Path
    from updater.interpolate import interpolate

    cases = json.loads(Path("cases.json").read_text())
    nix = json.loads(Path("nix.json").read_text())
    for case, nix_out in zip(cases, nix, strict=True):
        py_out = interpolate(case["template"], case["vars"])
        if not (py_out == nix_out == case["expected"]):
            msg = (
                f"interpolate divergence in case {case['name']!r}:\n"
                f"  template = {case['template']!r}\n"
                f"  vars     = {case['vars']}\n"
                f"  nix      = {nix_out!r}\n"
                f"  python   = {py_out!r}\n"
                f"  expected = {case['expected']!r}"
            )
            raise SystemExit(msg)
    print(f"{len(cases)} cases: Nix interpolate == Python interpolate == expected")
    PY
    touch $out
  ''
