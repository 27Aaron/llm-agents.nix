# A fetchurl whose URL is a template interpolated with an arbitrary `vars`
# attrset (see lib/interpolate.nix). This is the single templated-URL primitive
# shared between a package's build and its declarative updater, so the two can
# never describe different URLs. Any extra arguments (hash, name, ...) pass
# straight through to fetchurl.
#
#   fetchurlTemplate {
#     urlTemplate = "https://host/{version}/tool-{platform}.tar.gz";
#     vars = { version = "1.2.3"; platform = "linux-x64"; };
#     hash = "sha256-...";
#   }
{ fetchurl, interpolate }:

{
  urlTemplate,
  vars,
  ...
}@args:
fetchurl (
  (builtins.removeAttrs args [
    "urlTemplate"
    "vars"
  ])
  // {
    url = interpolate urlTemplate vars;
  }
)
