{
  lib,
  stdenv,
  flake,
  fetchFromGitHub,
  rustPlatform,
  makeWrapper,
  git,
  gh,
  openssh,
  bashInteractive,
  coreutils,
  procps,
  versionCheckHook,
  versionCheckHomeHook,
}:

let
  runtimeTools = [
    git
    gh
    openssh
    bashInteractive
    coreutils
  ]
  ++ lib.optionals stdenv.hostPlatform.isLinux [
    procps
  ];
in

rustPlatform.buildRustPackage (finalAttrs: {
  pname = "luvus";
  version = "0.11.0";

  src = fetchFromGitHub {
    owner = "RizRiyz";
    repo = "luvus";
    tag = "v${finalAttrs.version}";
    hash = "sha256-aKL/5N0E91IVIG7drMwKozNQy/bzy/78VdNCl67Dunc=";
  };

  cargoHash = "sha256-CqRDKuHC5kwIdGXLdpehBRoV1kE+Vj2Mj7xix3anz9k=";

  nativeBuildInputs = [ makeWrapper ];

  doCheck = false;

  postFixup = ''
    wrapProgram $out/bin/luvus \
      --prefix PATH : ${lib.makeBinPath runtimeTools}
  '';

  doInstallCheck = true;
  nativeInstallCheckInputs = [
    versionCheckHook
    versionCheckHomeHook
  ];

  passthru.category = "Workflow & Project Management";

  meta = {
    description = "Mission control for your AI coding agents";
    homepage = "https://luvus.dev";
    changelog = "https://github.com/RizRiyz/luvus/releases/tag/v${finalAttrs.version}";
    license = lib.licenses.agpl3Plus;
    sourceProvenance = [ lib.sourceTypes.fromSource ];
    maintainers = with flake.lib.maintainers; [ r17x ];
    mainProgram = "luvus";
    platforms = lib.platforms.unix;
  };
})
