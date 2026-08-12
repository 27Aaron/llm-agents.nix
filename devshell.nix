{ pkgs, perSystem }:
pkgs.mkShellNoCC {
  packages = [
    # Linter for package definitions (see rules/, sgconfig.yml)
    pkgs.ast-grep

    # Tools needed for update scripts
    pkgs.bash
    # Sandbox for updater code (.github/ci/update.py); Linux-only.
    (pkgs.lib.optional pkgs.stdenv.isLinux pkgs.bubblewrap)
    pkgs.coreutils
    pkgs.curl
    pkgs.gh
    pkgs.gnugrep
    pkgs.gnused
    pkgs.jq
    pkgs.nix-update
    pkgs.nodejs
    pkgs.nushell

    # Formatter
    perSystem.self.formatter
  ];

  shellHook = ''
    export PRJ_ROOT=$PWD
  '';
}
