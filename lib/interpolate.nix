# Nix mirror of Python's str.format: replace every `{name}` placeholder in
# `template` with `vars.name`, for whatever names `vars` carries. Unlike
# str.format, unknown placeholders are left as-is (replaceStrings only touches
# the keys it is given), and extra vars are simply unused.
#
#   interpolate "a/{version}/b-{platform}" { version = "1.2"; platform = "x64"; }
#   => "a/1.2/b-x64"
template: vars:
builtins.replaceStrings (map (name: "{${name}}") (
  builtins.attrNames vars
)) (builtins.attrValues vars) template
