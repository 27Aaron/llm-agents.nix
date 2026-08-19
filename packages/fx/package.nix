{
  lib,
  stdenv,
  fetchFromGitHub,
  zig,
  versionCheckHook,
  versionCheckHomeHook,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "fx";
  version = "0.0.3";

  src = fetchFromGitHub {
    owner = "vercel-labs";
    repo = "fx";
    tag = "v${finalAttrs.version}";
    hash = "sha256-oKDTCdHWe9kRmgMuty3s0J1urxPv5xutwlf/pWkXjYs=";
  };

  nativeBuildInputs = [ zig.hook ];

  zigBuildFlags = [ "-Doptimize=ReleaseSafe" ];

  doCheck = false;

  doInstallCheck = true;
  nativeInstallCheckInputs = [
    versionCheckHook
    versionCheckHomeHook
  ];

  passthru.category = "AI Coding Agents";

  meta = with lib; {
    description = "Tiny, open, embeddable, native coding agent";
    homepage = "https://github.com/vercel-labs/fx";
    changelog = "https://github.com/vercel-labs/fx/releases/tag/v${finalAttrs.version}";
    license = licenses.asl20;
    sourceProvenance = with sourceTypes; [ fromSource ];
    maintainers = with maintainers; [ ];
    mainProgram = "fx";
    platforms = platforms.unix;
  };
})
