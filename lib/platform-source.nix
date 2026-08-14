# Select the prebuilt release artifact for the host platform, using the
# per-platform hashes stored in a package's hashes.json.
#
# The URL scheme and platform map are the SAME data the declarative updater
# needs (see scripts/updater/run.py, kind = "platform"). Declare them once here
# via `urlTemplate` + `platforms`; this returns both the `src` for the build and
# an `updater` fragment for `passthru.updater`, so the two can never diverge.
{ stdenv, fetchurl }:

{
  # Path to the package's hashes.json ({ version, hashes.<system> }).
  hashesFile,
  # Maps nix system -> platform token substituted into the URL.
  platforms,
  # Canonical URL with {version}/{platform} placeholders. Shared verbatim with
  # the updater. Prefer this over `url`.
  urlTemplate ? null,
  # Legacy: { version, platform }: URL. Kept for callers not yet on urlTemplate;
  # such callers get `updater = null` (no single-source-of-truth guarantee).
  url ? null,
}:

let
  versionData = builtins.fromJSON (builtins.readFile hashesFile);
  inherit (versionData) version;
  system = stdenv.hostPlatform.system;
  token = platforms.${system} or (throw "Unsupported system: ${system}");
  artifactUrl =
    if urlTemplate != null then
      builtins.replaceStrings [ "{version}" "{platform}" ] [ version token ] urlTemplate
    else
      url {
        inherit version;
        platform = token;
      };
in
{
  inherit version;
  platforms = builtins.attrNames platforms;
  src = fetchurl {
    url = artifactUrl;
    hash = versionData.hashes.${system};
  };
  # Ready-to-merge `passthru.updater` fragment (add a `versionSource`). Derived
  # from the same urlTemplate + platform map as `src`. Null under legacy `url`.
  updater =
    if urlTemplate != null then
      {
        kind = "platform";
        inherit urlTemplate platforms;
      }
    else
      null;
}
