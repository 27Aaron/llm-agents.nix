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

  # writeShellApplication, but the body is a Nushell script instead of bash:
  # adds a nu shebang, puts runtimeInputs on PATH, and validates the script
  # parses at build time with nu-check (the nushell analogue of shellcheck).
  writeNushellApplication =
    {
      name,
      text,
      runtimeInputs ? [ ],
    }:
    pkgs.writeTextFile {
      inherit name;
      executable = true;
      destination = "/bin/${name}";
      text = ''
        #!${lib.getExe pkgs.nushell}
      ''
      + lib.optionalString (runtimeInputs != [ ]) ''
        $env.PATH = ("${lib.makeBinPath runtimeInputs}" | split row (char esep) | append $env.PATH)
      ''
      + "\n"
      + text;
      checkPhase = ''
        ${lib.getExe pkgs.nushell} --no-config-file --commands "nu-check --debug $target | ignore"
      '';
    };

  # Check-only nushell parse validator; see scripts/treefmt-nu-check.nu.
  # NB: the binary must NOT be named "nu-check". Nushell running a script whose
  # name collides with a builtin resolves the internal `nu-check` call to the
  # (flagless) external script itself, breaking `nu-check --debug`.
  nu-parse-check = writeNushellApplication {
    name = "nu-parse-check";
    text = builtins.readFile ./../../scripts/treefmt-nu-check.nu;
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

  # Nushell scripts: parse-check only (see nu-parse-check above)
  settings.formatter.nu-check = {
    command = "${nu-parse-check}/bin/nu-parse-check";
    includes = [ "*.nu" ];
  };
}
