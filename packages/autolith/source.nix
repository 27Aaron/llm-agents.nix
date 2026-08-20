{ fetchFromGitHub }:

let
  version = "0.35.0";
in
{
  inherit version;

  src = fetchFromGitHub {
    owner = "lambda-symbolics";
    repo = "autolith";
    tag = "v${version}";
    hash = "sha256-a26Tkz+VsRCA5PEl3mUPfLM8RMnmVYE4IeojRt8M6eo=";
  };
}
