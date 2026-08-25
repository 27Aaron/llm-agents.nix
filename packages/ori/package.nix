{
  lib,
  flake,
  stdenv,
  mkUpdater,
  platformSource,
}:

let
  source = platformSource {
    hashesFile = ./hashes.json;
    platforms = {
      x86_64-linux = "linux-x64";
      aarch64-linux = "linux-arm64";
      aarch64-darwin = "darwin-arm64";
    };
    urlTemplate = "https://github.com/OpenRouterLabs/ori-releases/releases/download/{version}/ori-{platform}";
  };
in
stdenv.mkDerivation {
  pname = "ori";
  inherit (source) version src;

  dontUnpack = true;
  dontStrip = true;

  installPhase = ''
    runHook preInstall
    install -Dm755 $src $out/bin/ori
    runHook postInstall
  '';

  passthru.category = "AI Coding Agents";
  passthru.updater = mkUpdater (
    source.updater
    // {
      versionSource = {
        type = "github";
        owner = "OpenRouterLabs";
        repo = "ori-releases";
      };
    }
  );

  meta = with lib; {
    description = "OpenRouter CLI for managing agent environments across coding tools";
    homepage = "https://openrouter.ai/labs/ori";
    changelog = "https://github.com/OpenRouterLabs/ori-releases/releases";
    license = flake.lib.licenses.unfree;
    sourceProvenance = with sourceTypes; [ binaryNativeCode ];
    maintainers = with flake.lib.maintainers; [ shzhng ];
    mainProgram = "ori";
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
      "aarch64-darwin"
    ];
  };
}
