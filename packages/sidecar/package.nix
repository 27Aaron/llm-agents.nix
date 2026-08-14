{
  lib,
  flake,
  buildGoModule,
  fetchFromGitHub,
  versionCheckHook,
}:

buildGoModule rec {
  pname = "sidecar";
  version = "0.99.0";

  src = fetchFromGitHub {
    owner = "marcus";
    repo = "sidecar";
    tag = "v${version}";
    hash = "sha256-K5sExKjbdReKC1hn11FTWbv9Z8EAMtI4h//s93HXPzw=";
  };

  vendorHash = "sha256-TrUEkofD2a1An9OOBdLX3SH349BPzWqB10iPbs4Cou0=";

  subPackages = [ "cmd/sidecar" ];

  ldflags = [
    "-s"
    "-w"
    "-X=main.Version=${version}"
  ];

  doCheck = false;

  doInstallCheck = true;
  nativeInstallCheckInputs = [ versionCheckHook ];

  passthru.category = "Workflow & Project Management";

  meta = with lib; {
    description = "Terminal-based development companion for AI coding agents";
    homepage = "https://github.com/marcus/sidecar";
    changelog = "https://github.com/marcus/sidecar/releases/tag/v${version}";
    license = licenses.mit;
    sourceProvenance = with sourceTypes; [ fromSource ];
    maintainers = with flake.lib.maintainers; [ afterthought ];
    mainProgram = "sidecar";
    platforms = platforms.linux ++ platforms.darwin;
  };
}
