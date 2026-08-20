{
  fetchFromGitHub,
  lib,
  pkgs,
}:

let
  source = import ./source.nix { inherit fetchFromGitHub; };
in
(import ./upstream-package.nix {
  inherit pkgs;
  inherit (source) src;
}).overrideAttrs
  (old: {
    inherit (source) version;

    passthru = (old.passthru or { }) // {
      category = "AI Assistants";
    };

    meta = with lib; {
      description = "Live, self-modifying Common Lisp AI agent";
      homepage = "https://github.com/lambda-symbolics/autolith";
      changelog = "https://github.com/lambda-symbolics/autolith/releases/tag/v${source.version}";
      license = licenses.isc;
      sourceProvenance = with sourceTypes; [ fromSource ];
      maintainers = with maintainers; [ luciusmagn ];
      mainProgram = "autolith";
      platforms = [
        "x86_64-linux"
        "aarch64-linux"
        "aarch64-darwin"
      ];
    };
  })
