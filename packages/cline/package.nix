{
  lib,
  stdenv,
  platformSource,
  wrapBuddy,
  versionCheckHook,
  versionCheckHomeHook,
}:

let
  source = platformSource {
    hashesFile = ./hashes.json;
    platforms = {
      x86_64-linux = "linux-x64";
      aarch64-linux = "linux-arm64";
      aarch64-darwin = "darwin-arm64";
    };
    url =
      { version, platform }:
      "https://registry.npmjs.org/@cline/cli-${platform}/-/cli-${platform}-${version}.tgz";
  };
in
stdenv.mkDerivation {
  pname = "cline";
  inherit (source) version src;

  sourceRoot = "package";

  nativeBuildInputs = lib.optionals stdenv.hostPlatform.isLinux [ wrapBuddy ];

  dontBuild = true;
  dontStrip = true;

  installPhase = ''
    runHook preInstall

    mkdir -p $out/lib
    cp -r . $out/lib/cline
    mkdir -p $out/bin
    ln -s $out/lib/cline/bin/cline $out/bin/cline

    runHook postInstall
  '';

  doInstallCheck = true;
  nativeInstallCheckInputs = [
    versionCheckHook
    versionCheckHomeHook
  ];

  passthru.category = "AI Coding Agents";

  meta = {
    description = "Autonomous coding agent CLI";
    homepage = "https://cline.bot";
    changelog = "https://github.com/cline/cline/releases/tag/cli-v${source.version}";
    downloadPage = "https://www.npmjs.com/package/cline";
    license = lib.licenses.asl20;
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
    maintainers = [ ];
    mainProgram = "cline";
    platforms = source.platforms;
  };
}
