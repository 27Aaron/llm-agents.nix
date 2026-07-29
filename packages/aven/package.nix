{
  lib,
  fetchFromGitHub,
  rustPlatform,
  cacert,
  git,
  sqlite,
  versionCheckHook,
}:

rustPlatform.buildRustPackage (finalAttrs: {
  pname = "aven";
  version = "0.1.19";

  src = fetchFromGitHub {
    owner = "raine";
    repo = "aven";
    tag = "v${finalAttrs.version}";
    hash = "sha256-O061QVxle2f9UdGBNdgovBskpT1tpUiEqAVHbyChDtI=";
  };

  cargoHash = "sha256-fDM1ymMOmCUc7q7onb5Fn49frzXtmZO4hk9ESgbCBww=";

  # A handful of store tests assert display refs whose project key is inferred
  # from the checkout directory's name (e.g. "aven" -> "AVN"). Nix unpacks the
  # source into a directory called "source" (-> "SRC"), so rename it to "aven"
  # to match upstream's expectations. Paired with the git init in preCheck.
  postUnpack = ''
    mv source aven
    export sourceRoot=aven
  '';

  # Only build the CLI crate, not the aven-uniffi mobile bindings.
  cargoBuildFlags = [
    "--package"
    "aven"
  ];

  postInstall = ''
    install -d $out/share/aven
    cp -r skills $out/share/aven/skills
  '';

  # git: TUI tests infer the project from the checkout's git repo (see preCheck).
  # sqlite: cli_attachment_lifecycle integration tests shell out to `sqlite3`.
  # cacert: the sync client (reqwest + rustls-native-certs) loads system CA
  # certs when it is built, even for plain http://127.0.0.1 test servers, and
  # errors with "No CA certificates were loaded from the system" in the Linux
  # sandbox, which has none. Paired with SSL_CERT_FILE in preCheck.
  nativeCheckInputs = [
    cacert
    git
    sqlite
  ];

  checkFlags = [
    # chrono resolves a named TZ (e.g. TZ=America/New_York) only from a hardcoded
    # set of system paths (/usr/share/zoneinfo, ...) and ignores $TZDIR
    # (https://github.com/chronotope/chrono/issues/1265), so the DST offset test
    # cannot see a zoneinfo database in the hermetic sandbox and falls back to
    # UTC. Skip just that test; the rest of cli_local runs.
    "--skip=local_calendar_dates_use_offsets_across_daylight_saving_boundaries"
    # `aven backup` shells out to a `sqlite3 .backup` subprocess (busy_timeout=0)
    # while its own WAL connection to the same file is still open, so a WAL
    # checkpoint racing that lock surfaces as "database is locked". The window is
    # load-sensitive: it passes under light load but flakes on heavily parallel,
    # slower runners (seen on aarch64). Run the suite single-threaded to remove
    # the cross-test CPU contention that widens the race.
    "--test-threads=1"
  ];

  # A large share of the TUI tests create tasks without an explicit project and
  # rely on aven inferring one from the current directory's git repository
  # (src/projects.rs: git_root walks up for a `.git`). The Nix sandbox is not a
  # git repo, so inference yields nothing and the tasks fail with
  # "project-required". Initialise a repo at the check cwd so inference resolves.
  preCheck = ''
    export HOME=$(mktemp -d)
    export SSL_CERT_FILE=${cacert}/etc/ssl/certs/ca-bundle.crt
    git init -q .
  '';

  doInstallCheck = true;
  nativeInstallCheckInputs = [ versionCheckHook ];

  passthru.category = "Workflow & Project Management";

  meta = {
    description = "Local-first task manager for power users and agents";
    longDescription = ''
      Aven is a local-first task manager built for both humans and AI agents.
      It stores tasks offline in SQLite with optional self-hosted sync, exposes
      an agent-first CLI, ships a polished terminal UI, and keeps tasks
      markdown-native with unique IDs and workspace isolation.
    '';
    homepage = "https://github.com/raine/aven";
    changelog = "https://github.com/raine/aven/blob/v${finalAttrs.version}/CHANGELOG.md";
    license = lib.licenses.mit;
    mainProgram = "aven";
    maintainers = with lib.maintainers; [ sei40kr ];
    sourceProvenance = with lib.sourceTypes; [ fromSource ];
    platforms = lib.platforms.unix;
  };
})
