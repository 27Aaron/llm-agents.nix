{
  lib,
  flake,
  fetchFromGitHub,
  rustPlatform,
  installShellFiles,
  bashNonInteractive,
  coreutils,
  curl,
  findutils,
  gawk,
  git,
  gnused,
  versionCheckHook,
  versionCheckHomeHook,
}:

let
  hookPath = lib.makeBinPath [
    bashNonInteractive
    coreutils
    curl
    findutils
    gawk
    git
    gnused
  ];
in
rustPlatform.buildRustPackage (finalAttrs: {
  pname = "ai-memory";
  version = "1.30.0";

  src = fetchFromGitHub {
    owner = "akitaonrails";
    repo = "ai-memory";
    tag = "v${finalAttrs.version}";
    hash = "sha256-xXlrd+aIoIqWpbMlLXYoVjJrzZS2nTmSKj0S1FcFiI0=";
  };

  cargoHash = "sha256-ixwBh2sqVIAPQIL6wA5ljM/yRnz3s41R69fn/BYitbQ=";

  cargoBuildFlags = [
    "--package"
    "ai-memory-cli"
  ];
  cargoTestFlags = finalAttrs.cargoBuildFlags ++ [
    "--bin"
    "ai-memory"
  ];

  env.TAILWIND_SKIP = "1";

  postPatch = ''
    # Git is part of the CLI's runtime contract (wiki history, repository
    # routing, bootstrap, and managed workstreams). Use its Nix store path so
    # installed native hook commands do not depend on an ambient PATH.
    substituteInPlace \
      crates/ai-memory-cli/src/commands/hook_capture.rs \
      crates/ai-memory-consolidate/src/bootstrap.rs \
      crates/ai-memory-hooks/src/router.rs \
      crates/ai-memory-wiki/src/git.rs \
      crates/ai-memory-workstream/src/repository.rs \
      --replace-fail 'Command::new("git")' 'Command::new("${lib.getExe git}")'
  '';

  nativeBuildInputs = [ installShellFiles ];

  postInstall = ''
    # Lifecycle hook scripts are runtime assets. The CLI probes hooks/ beside
    # its executable, while the canonical copy belongs under share/.
    mkdir -p $out/share/ai-memory
    cp -r hooks $out/share/ai-memory/
    find $out/share/ai-memory/hooks -type f -name '*.ps1' -delete
    find $out/share/ai-memory/hooks -depth -type d -empty -delete

    # Hooks run later from agent configuration, outside the main process.
    # Give every entry point a NixOS-safe interpreter and tool PATH before it
    # calls dirname to find the shared helper.
    for hook in $out/share/ai-memory/hooks/*/*.sh; do
      substituteInPlace "$hook" \
        --replace-fail \
          '#!/bin/sh' \
          $'#!${lib.getExe bashNonInteractive}\nPATH=${hookPath}:$PATH\nexport PATH'
    done

    ln -s ../share/ai-memory/hooks $out/bin/hooks

    installShellCompletion --cmd ai-memory \
      --bash <($out/bin/ai-memory completions bash) \
      --fish <($out/bin/ai-memory completions fish) \
      --zsh <($out/bin/ai-memory completions zsh)
  '';

  doInstallCheck = true;
  nativeInstallCheckInputs = [
    versionCheckHook
    versionCheckHomeHook
  ];
  versionCheckProgramArg = "--version";

  passthru.category = "Memory & Code Intelligence";

  meta = {
    description = "Long-term memory for AI coding agents";
    homepage = "https://github.com/akitaonrails/ai-memory";
    changelog = "https://github.com/akitaonrails/ai-memory/releases/tag/v${finalAttrs.version}";
    license = lib.licenses.mit;
    sourceProvenance = with lib.sourceTypes; [ fromSource ];
    maintainers = with flake.lib.maintainers; [ mulatta ];
    mainProgram = "ai-memory";
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
      "aarch64-darwin"
    ];
  };
})
