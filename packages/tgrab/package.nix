{
  lib,
  flake,
  fetchFromGitHub,
  rustPlatform,
}:

rustPlatform.buildRustPackage (finalAttrs: {
  pname = "tgrab";
  version = "0.1.0";

  src = fetchFromGitHub {
    owner = "ryoppippi";
    repo = "tgrab";
    tag = "v${finalAttrs.version}";
    hash = "sha256-QXLHZ0HztxUcANgzGlQ8Wg9nOnTB7Lk8cCBVH6f5a8E=";
  };

  cargoHash = "sha256-9/wVARIR2nsiNotxFifYkzbVf8P2oAxz13jx86DAVrk=";

  env.RUSTFLAGS = "--cfg reqwest_unstable";

  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck
    $out/bin/tgrab --help > /dev/null
    runHook postInstallCheck
  '';

  passthru.category = "Utilities";

  meta = {
    description = "Fetch text content from YouTube, Twitter/X, and Bluesky";
    homepage = "https://github.com/ryoppippi/tgrab";
    changelog = "https://github.com/ryoppippi/tgrab/releases";
    license = lib.licenses.mit;
    sourceProvenance = with lib.sourceTypes; [ fromSource ];
    maintainers = with flake.lib.maintainers; [ ryoppippi ];
    mainProgram = "tgrab";
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
      "aarch64-darwin"
    ];
  };
})
