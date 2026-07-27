{
  lib,
  fetchFromGitHub,
  fetchurl,
  rustPlatform,
  jq,
  pkg-config,
  stdenv,
  libiconv,
  versionCheckHook,
  versionCheckHomeHook,
}:

let
  # build.rs embeds a LiteLLM pricing snapshot. Without a local file it
  # downloads model_prices_and_context_window.json at build time, which the
  # sandbox forbids. Pin the same litellm rev as upstream's flake.lock
  # (nodes.litellm.locked) and pass it via CCUSAGE_PRICING_JSON_PATH.
  litellmRev = "34561482ed092d78c296cab7999486022af5a938";
  litellm-pricing = fetchurl {
    url = "https://raw.githubusercontent.com/BerriAI/litellm/${litellmRev}/model_prices_and_context_window.json";
    hash = "sha256-jV/bRDNx+DNMKMsP9kvw82rRNexvdm7sdnzGLTt/gJI=";
  };
in
rustPlatform.buildRustPackage rec {
  pname = "ccusage";
  version = "20.0.18";

  src = fetchFromGitHub {
    owner = "ryoppippi";
    repo = "ccusage";
    tag = "v${version}";
    hash = "sha256-vtxaUrzX9389M6GIfdbgmt+Z3lwCb1XgcLtdNj1lFWo=";
  };

  sourceRoot = "${src.name}/rust";

  cargoHash = "sha256-/sJ4c7F8tuiTxo2sUqgpB6z3rEC0BZlLn1FToz1Oe+g=";

  cargoBuildFlags = [
    "-p"
    "ccusage"
    "--bin"
    "ccusage"
  ];

  doCheck = false;

  nativeBuildInputs = [
    jq
    pkg-config
  ];

  buildInputs = lib.optionals stdenv.hostPlatform.isDarwin [ libiconv ];

  env.CCUSAGE_PRICING_JSON_PATH = litellm-pricing;

  # The pricing snapshot above is pinned by hand while build.rs resolves it from
  # upstream's flake.lock, so the two drift apart on every version bump unless
  # the mismatch is fatal.
  preBuild = ''
    lockedRev=$(jq -r .nodes.litellm.locked.rev ../flake.lock)
    if [ "$lockedRev" != "${litellmRev}" ]; then
      echo "error: litellm pricing pin ${litellmRev} != upstream flake.lock $lockedRev" >&2
      echo "       update litellmRev and its hash in packages/ccusage/package.nix" >&2
      exit 1
    fi
  '';

  doInstallCheck = true;

  nativeInstallCheckInputs = [
    versionCheckHook
    versionCheckHomeHook
  ];

  passthru.category = "Usage Analytics";

  meta = with lib; {
    description = "Analyze coding agent CLI token usage and costs from local data";
    homepage = "https://github.com/ryoppippi/ccusage";
    changelog = "https://github.com/ryoppippi/ccusage/releases/tag/v${version}";
    license = licenses.mit;
    sourceProvenance = with lib.sourceTypes; [ fromSource ];
    maintainers = with maintainers; [ ryoppippi ];
    mainProgram = "ccusage";
    platforms = platforms.all;
  };
}
