# Select the prebuilt release artifact for the host platform, using the
# per-platform hashes stored in a package's hashes.json.
#
# A thin per-platform layer over `fetchurlTemplate`: it picks the host system's
# token + hash and interpolates {version}/{platform} into the shared urlTemplate.
# The URL scheme and platform map are the SAME data the declarative updater
# needs (see scripts/updater/run.py, kind = "platform"), so this returns both
# the `src` for the build and an `updater` fragment — declared once, never
# divergent.
{ stdenv, fetchurlTemplate }:

{
  # Path to the package's hashes.json ({ version, hashes.<system> }).
  hashesFile,
  # Maps nix system -> the URL variables for that platform. A string is
  # shorthand for the single {platform} var; an attrset supplies arbitrary vars
  # (e.g. { os = "linux"; cpu = "x86_64"; }) interpolated into urlTemplate.
  platforms,
  # Canonical URL with {version} + platform placeholders, shared verbatim with
  # the updater fragment below.
  urlTemplate,
}:

let
  versionData = builtins.fromJSON (builtins.readFile hashesFile);
  inherit (versionData) version;
  system = stdenv.hostPlatform.system;
  entry = platforms.${system} or (throw "Unsupported system: ${system}");
  platformVars = if builtins.isAttrs entry then entry else { platform = entry; };
in
{
  inherit version;
  platforms = builtins.attrNames platforms;
  src = fetchurlTemplate {
    inherit urlTemplate;
    vars = {
      inherit version;
    }
    // platformVars;
    hash = versionData.hashes.${system};
  };
  # Ready-to-merge `passthru.updater` fragment (add a `versionSource`). Derived
  # from the same urlTemplate + platform map as `src`.
  updater = {
    kind = "platform";
    inherit urlTemplate platforms;
  };
}
