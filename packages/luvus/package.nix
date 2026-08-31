{
  lib,
  stdenv,
  flake,
  fetchFromGitHub,
  rustPlatform,
  makeWrapper,
  curl,
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
  version = "0.13.2";

  src = fetchFromGitHub {
    owner = "RizRiyz";
    repo = "luvus";
    tag = "v${finalAttrs.version}";
    hash = "sha256-YSfp03fzYRq6vG8BEbmOWg6noH2wdPvzlg+EvLGOSdY=";
  };

  cargoHash = "sha256-2KSOlA8Hjoav300+gFlTA/gD4/F0yW7BPrtW3dCh014=";

  nativeBuildInputs = [ makeWrapper ];

  # needs git worktrees and curl for a file:// fetch
  nativeCheckInputs = [
    curl
    git
  ];

  # flaky: spawn real PTYs/processes and race under load
  checkFlags = [
    "--skip=app::tests::clicking_a_pane_title_shows_the_real_command"
    "--skip=app::tests::keyboard_copy_mode_yanks_history_and_cancel_restores_its_viewport"
    "--skip=app::tests::resize_yields_to_pane_title_and_zoom_but_still_grabs_the_seam"
    "--skip=app::tests::resume_session_opens_pane"
    "--skip=platform::tests::process_tree_finds_this_process_and_its_children"
    "--skip=app::settings::tests::enter_routes_an_installed_theme_through_removal"
    # opens the git dashboard on the build dir, which is not a repository
    "--skip=app::diff::tests::dashboard_diff_click_opens_a_tab_then_reuses_it"
    # expect $HOME to exist, which it does not in the sandbox;
    # providing one makes tests that persist config under it race each other
    "--skip=app::picker::tests::home_row_and_go_to_footer_are_interactive"
    "--skip=app::tests::spawn_cwds_skips_missing_dirs_and_anchors_on_home"
  ];

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
