# Generate a nixpkgs-standard `passthru.updateScript` from a validated
# `passthru.updater` config. The script carries its own tools (python3, nix,
# git, and per-kind bun/nodejs), so nothing about the update lives in CI: a
# single `nix run .#<pkg>.updateScript` — or nixpkgs' update.nix, or nix-update
# — drives it. It runs `scripts/updater/run.py` against the config, which the
# derivation already carries as data.
{
  lib,
  writeShellApplication,
  python3,
  nix,
  git,
  cacert,
  bun,
  nodejs,
}:
{
  name,
  config,
}:
let
  # Tools each kind's flow shells out to, on top of the common set.
  extraToolsByKind = {
    "npm" = [ nodejs ];
    "bun-github" = [
      bun
      git
    ];
  };
  extraTools = extraToolsByKind.${config.kind} or [ ];
  # The dependency-hash kinds build `.#<name>`; the attr is the package's own
  # name, so inject it rather than restating it in every config.
  needsFlakeAttr = builtins.elem config.kind [
    "github-source"
    "npm"
  ];
  resolvedConfig = if needsFlakeAttr then config // { flakeAttr = ".#${name}"; } else config;
  configJson = builtins.toJSON resolvedConfig;
in
writeShellApplication {
  name = "update-${name}";
  runtimeInputs = [
    python3
    nix
    git
    cacert
  ]
  ++ extraTools;
  text = ''
    # Run from the flake root (nix run / update.nix both preserve cwd there).
    export SSL_CERT_FILE="${cacert}/etc/ssl/certs/ca-bundle.crt"
    export PYTHONPATH="$PWD/scripts''${PYTHONPATH:+:$PYTHONPATH}"
    exec python3 -m updater.run \
      --pkg-dir ${lib.escapeShellArg "packages/${name}"} \
      --config ${lib.escapeShellArg configJson}
  '';
}
