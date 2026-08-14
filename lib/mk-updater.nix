# Validate and normalize a declarative `passthru.updater` config.
#
# A package that can be updated by one of the shared flows declares its recipe
# as data instead of shipping a packages/<name>/update.py script:
#
#   passthru.updater = mkUpdater {
#     kind = "github-source";
#     purl = "pkg:github/charmbracelet/crush";
#     flakeAttr = ".#crush";
#     depHashKey = "vendorHash";
#   };
#
# CI reads this attrset (nix eval --json) and runs `python3 -m updater.run`,
# which turns the purl back into the flow's arguments. See scripts/updater/run.py.
#
# This helper only validates required fields at eval time so a malformed config
# fails `nix flake check` rather than the next weekly update run.
{ lib }:
let
  # kind -> attributes the runner requires for that kind.
  requiredByKind = {
    "github-source" = [
      "purl"
      "flakeAttr"
      "depHashKey"
    ];
    "npm" = [
      "purl"
      "flakeAttr"
    ];
    "bun-github" = [ "purl" ];
    "platform" = [
      "versionSource"
      "urlTemplate"
      "platforms"
    ];
    "manifest" = [
      "manifestUrl"
      "platformMap"
    ];
  };
in
config:
let
  kind = config.kind or (throw "passthru.updater: missing required attribute 'kind'");
  required =
    requiredByKind.${kind} or (throw (
      "passthru.updater: unknown kind '${kind}' (known: "
      + lib.concatStringsSep ", " (lib.attrNames requiredByKind)
      + ")"
    ));
  missing = lib.filter (field: !(config ? ${field})) required;
in
if missing != [ ] then
  throw "passthru.updater (kind '${kind}'): missing ${lib.concatStringsSep ", " missing}"
else
  config
