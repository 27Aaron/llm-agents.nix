{ pkgs, lib, ... }:
let
  mypy-check = pkgs.writeShellApplication {
    name = "mypy-check";
    runtimeInputs = [
      pkgs.mypy
      pkgs.findutils
      pkgs.python3Packages.pyelftools
    ];
    text = builtins.readFile ./../../scripts/check.sh;
  };

  # Check-only: nushell has no mature autoformatter (nufmt is alpha), so we
  # validate that each .nu file parses. nu-check prints true/false and always
  # exits 0, so translate a false into a non-zero exit for treefmt.
  nu-check = pkgs.writeShellApplication {
    name = "nu-check";
    runtimeInputs = [ pkgs.nushell ];
    text = ''
      status=0
      for f in "$@"; do
        if [ "$(nu --no-config-file --commands "nu-check '$f'")" != "true" ]; then
          echo "nu-check: parse error in $f" >&2
          nu --no-config-file --commands "nu-check --debug '$f'" >&2 || true
          status=1
        fi
      done
      exit "$status"
    '';
  };
in
{
  package = pkgs.treefmt;

  projectRootFile = "flake.lock";

  programs.deadnix.enable = true;
  programs.nixfmt.enable = true;

  programs.mdformat.enable = true;

  programs.shellcheck.enable = true;
  programs.shfmt.enable = true;

  programs.taplo.enable = true;
  programs.yamlfmt.enable = true;

  # Python formatting and linting
  programs.ruff-format.enable = true;
  programs.ruff-check.enable = true;

  settings.formatter.deadnix.pipeline = "nix";
  settings.formatter.deadnix.priority = 1;
  settings.formatter.nixfmt.pipeline = "nix";
  settings.formatter.nixfmt.priority = 2;

  settings.formatter.shellcheck.pipeline = "shell";
  settings.formatter.shellcheck.priority = 1;
  settings.formatter.shfmt.pipeline = "shell";
  settings.formatter.shfmt.priority = 2;

  settings.formatter.ruff-check.pipeline = "python";
  settings.formatter.ruff-check.priority = 1;
  settings.formatter.ruff-format.pipeline = "python";
  settings.formatter.ruff-format.priority = 2;

  # ast-grep lint rules (../../rules via sgconfig.yml at project root) for
  # anti-patterns Nix evaluation won't reject; check-only, no rewrites.
  settings.formatter.ast-grep-check = {
    command = lib.getExe pkgs.ast-grep;
    options = [
      "scan"
      "--error"
    ];
    includes = [
      "*.nix"
      "*.py"
    ];
  };

  # Custom mypy check that handles our update.py scripts correctly
  settings.formatter.mypy-check = {
    command = "${mypy-check}/bin/mypy-check";
    includes = [ "*.py" ];
    pipeline = "python";
    priority = 3;
  };

  # Nushell scripts: parse-check only (see nu-check above)
  settings.formatter.nu-check = {
    command = "${nu-check}/bin/nu-check";
    includes = [ "*.nu" ];
  };
}
