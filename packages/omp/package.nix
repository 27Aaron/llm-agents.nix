{
  lib,
  stdenv,
  stdenvNoCC,
  fetchurl,
  fetchFromGitHub,
  bun2nixLib,
  bun,
  rustc,
  cargo,
  rustPlatform,
  pkg-config,
  makeWrapper,
  rcodesign,
  formatelf,
  zlib,
  libopus,
  python3,
  zig,
  cmake,
  libpulseaudio,
  unzip,
  pipewire,
}:

let
  versionData = builtins.fromJSON (builtins.readFile ./hashes.json);
  inherit (versionData) version hash cargoHash;
  platformsBySystem = {
    aarch64-darwin = {
      bunTemplate = {
        name = "bun-darwin-aarch64";
        hash = "sha256-2LliIYKK1vl6x6wKt+lYcjQa92MAHogD6CZ2UsJlJiA=";
      };
      nativeLib = "libpi_natives.dylib";
      nodeTag = "darwin-arm64";
    };
    aarch64-linux = {
      bunTemplate = {
        name = "bun-linux-aarch64";
        hash = "sha256-on/7Y6gxA3WDbg1vZorhf6jY0YuIw3yCHGUzGXOhmjs=";
      };
      nativeLib = "libpi_natives.so";
      nodeTag = "linux-arm64";
    };
    x86_64-linux = {
      bunTemplate = {
        name = "bun-linux-x64";
        hash = "sha256-lR7iruhV8IWVruxiJSJqKY0/6oOj3NZGXAnLzN9+hI8=";
      };
      nativeLib = "libpi_natives.so";
      nodeTag = "linux-x64";
    };
  };
  platform =
    platformsBySystem.${stdenv.hostPlatform.system}
      or (throw "Unsupported platform for omp: ${stdenv.hostPlatform.system}");
  # Bun 1.3.14 adds Bun.Image, but its compiler corrupts Nix-patched
  # executable templates: https://github.com/oven-sh/bun/issues/31023
  # Bun 1.3.13 writes OMP into the unmodified 1.3.14 template instead.
  # Remove this split after a stable Bun release contains oven-sh/bun#31024.
  bunRuntimeVersion = "1.3.14";
  bunRuntimeTemplate = stdenvNoCC.mkDerivation {
    pname = "omp-bun-runtime-template";
    version = bunRuntimeVersion;

    src = fetchurl {
      url = "https://github.com/oven-sh/bun/releases/download/bun-v${bunRuntimeVersion}/${platform.bunTemplate.name}.zip";
      inherit (platform.bunTemplate) hash;
    };

    sourceRoot = platform.bunTemplate.name;
    nativeBuildInputs = [ unzip ];
    dontConfigure = true;
    dontBuild = true;
    # The ELF must keep its original three PT_LOAD segments. It is build data,
    # not an executable that runs in this derivation.
    dontFixup = true;

    installPhase = ''
      runHook preInstall
      install -Dm755 ./bun $out/libexec/bun
      runHook postInstall
    '';
  };
  rustTarget = stdenv.hostPlatform.rust.rustcTarget;

  src = fetchFromGitHub {
    owner = "can1357";
    repo = "oh-my-pi";
    tag = "v${version}";
    inherit hash;
  };
in
stdenv.mkDerivation {
  pname = "omp";
  inherit version src;
  patches = [ ./use-bun-executable-template.patch ];

  cargoDeps = rustPlatform.fetchCargoVendor {
    name = "omp-${version}-cargo-vendor";
    inherit src;
    hash = cargoHash;
  };

  nativeBuildInputs = [
    bun2nixLib.hook
    bun
    rustc
    cargo
    rustPlatform.cargoSetupHook
    # bindgen (zlob, maudio-sys) needs libclang plus the correct clang flags
    # to find libc headers such as pthread.h.
    rustPlatform.bindgenHook
    pkg-config
    makeWrapper
    zig
    # audiopus_sys (new dependency in 17.1.3) builds bundled libopus via cmake
    cmake
  ]
  ++ lib.optionals stdenv.hostPlatform.isLinux [ formatelf ]
  ++ lib.optionals stdenv.hostPlatform.isDarwin [ rcodesign ];

  buildInputs = lib.optionals stdenv.hostPlatform.isLinux [
    stdenv.cc.cc.lib
    zlib
    # audiopus_sys links against opus (found via pkg-config)
    libopus
    # pi-natives' wayland-pipewire feature links system libpipewire (pkg-config)
    pipewire
  ];

  # cmake is only needed by the audiopus_sys build script, not for configuring
  # this derivation itself.
  dontUseCmakeConfigure = true;

  # smallvec's `specialization` feature requires nightly Rust.
  # RUSTC_BOOTSTRAP=1 enables nightly features on stable rustc.
  env = {
    RUSTC_BOOTSTRAP = 1;
    # audiopus_sys' bundled opus ships a cmake_minimum_required older than
    # what nixpkgs' cmake 4.x still accepts.
    CMAKE_POLICY_VERSION_MINIMUM = "3.5";
  };

  bunDeps = bun2nixLib.fetchBunDeps {
    bunNix = ./bun.nix;
  };

  # Drop robomp-web workspace: its devDependencies aren't needed for the CLI.
  postUnpack = ''
        rm -rf $sourceRoot/python/robomp/web
        ROOT="$sourceRoot" ${lib.getExe python3} -c "
    import json, re, os
    root = os.environ['ROOT']

    with open(f'{root}/package.json') as f:
        pkg = json.load(f)
    ws = pkg.get('workspaces', {})
    if isinstance(ws, dict) and 'packages' in ws:
        ws['packages'] = [w for w in ws['packages'] if 'robomp/web' not in w]
    elif isinstance(ws, list):
        pkg['workspaces'] = [w for w in ws if 'robomp/web' not in w]
    with open(f'{root}/package.json', 'w') as f:
        json.dump(pkg, f, indent=2)
        f.write('\\n')

    # bun.lock uses trailing commas (JSONC), strip them for stdlib json
    with open(f'{root}/bun.lock') as f:
        text = re.sub(r',\s*([}\]])', r'\1', f.read())
    lock = json.loads(text)
    lock.get('workspaces', {}).pop('python/robomp/web', None)
    lock.get('packages', {}).pop('robomp-web', None)
    for k in list(lock.get('packages', {})):
        if k.startswith('robomp-web/'):
            del lock['packages'][k]
    with open(f'{root}/bun.lock', 'w') as f:
        json.dump(lock, f, indent=2)
        f.write('\\n')
    "
  '';

  # We handle build and install ourselves
  dontUseBunBuild = true;
  dontUseBunInstall = true;
  dontRunLifecycleScripts = true;

  # bun compile embeds JS in the binary; stripping would break it
  dontStrip = true;

  postPatch = ''
    # Strip ^ and ~ prefixes: bun resolves range specifiers via the npm
    # registry, which is unreachable in the sandbox.
    for f in package.json packages/*/package.json; do
      if [ -f "$f" ]; then
        sed -i 's/: "\^/: "/g; s/: "~/: "/g' "$f"
      fi
    done
    sed -i 's/: "\^/: "/g; s/: "~/: "/g' bun.lock


    # Placeholder client bundle avoids building the full React dashboard.
    cat > packages/stats/src/embedded-client.generated.txt <<'PLACEHOLDER'
    export const EMBEDDED_CLIENT_ARCHIVE_TAR_GZ_BASE64 = "";
    PLACEHOLDER
  '';

  buildPhase = ''
    runHook preBuild

    # Native node modules like @napi-rs/cli need libstdc++ at build time
    ${lib.optionalString stdenv.hostPlatform.isLinux ''
      export LD_LIBRARY_PATH="${lib.makeLibraryPath [ stdenv.cc.cc.lib ]}"
    ''}

    # Build the Rust native addon
    echo "Building Rust native addon..."
    cargo build --release -p pi-natives \
      ${lib.optionalString stdenv.hostPlatform.isLinux "--features wayland-pipewire"} \
      --target ${rustTarget} --target-dir target

    # Install the native addon where the JS code expects it
    mkdir -p packages/natives/native
    cp target/${rustTarget}/release/${platform.nativeLib} \
       packages/natives/native/pi_natives.${platform.nodeTag}.node

    # Generate the napi type definitions and JS loader
    napiBin="$(pwd)/node_modules/.bin/napi"
    if [ -x "$napiBin" ]; then
      "$napiBin" build \
        --manifest-path crates/pi-natives/Cargo.toml \
        --package-json-path packages/natives/package.json \
        --platform \
        --no-js \
        --dts index.d.ts \
        -o packages/natives/native \
        --release \
        || echo "napi CLI post-processing failed; using cargo output directly"
    fi

    # Generate runtime enum exports from const enums in the type definitions
    if [ -f packages/natives/scripts/gen-enums.ts ] && \
       [ -f packages/natives/native/index.d.ts ]; then
      bun packages/natives/scripts/gen-enums.ts || true
    fi

    # --generate embeds the omp:// docs index; without it the script is a no-op
    # and the binary ships no docs, breaking omp:// reads.
    echo "Generating docs index..."
    bun packages/coding-agent/scripts/generate-docs-index.ts --generate

    # Generate the embedded stats dashboard client bundle. Bun.Archive.write
    # stamps each tar header with the current time, so normalize the archive
    # afterwards to keep the compiled binary reproducible (issue #6534).
    echo "Generating embedded stats dashboard..."
    bun --cwd packages/stats scripts/generate-client-bundle.ts --generate
    bun ${./normalize-embedded-client.ts} \
      packages/stats/src/embedded-client.generated.txt

    # Generate the embedded HTML-export tool-views bundle (coding-agent prepack
    # step): export/html/index.ts text-imports ./tool-views.generated.js, which
    # bun compile cannot resolve unless it is generated first.
    echo "Generating embedded HTML-export tool-views..."
    bun --cwd packages/collab-web scripts/build-tool-views.ts

    # Since v16.4.6 mupdf is bundled into the binary and its wasm blob is
    # embedded via a generated helper (upstream gen:mupdf); --external mupdf
    # no longer works because the compiled bunfs cannot resolve it.
    echo "Embedding mupdf wasm..."
    bun packages/coding-agent/scripts/embed-mupdf-wasm.ts --generate

    # Compile the standalone binary. Since v16.4.6 the binary needs the
    # in-memory omp-legacy-pi-modules virtual module, which only the
    # Bun.build() plugin from upstream's compile-binary.ts can provide, so
    # drive that helper instead of `bun build --compile`.
    echo "Compiling standalone binary..."
    (cd packages/coding-agent && bun ${./compile-standalone.ts} "${bunRuntimeTemplate}/libexec/bun")

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p $out/lib/omp $out/bin
    cp dist/omp $out/lib/omp/omp
    # Ship the plain addon name: native.ts probes for it on every arch.
    cp packages/natives/native/pi_natives.${platform.nodeTag}.node $out/lib/omp/

    makeWrapper $out/lib/omp/omp $out/bin/omp \
      --set PI_SKIP_VERSION_CHECK 1 \
    ${lib.optionalString stdenv.hostPlatform.isLinux "--prefix LD_LIBRARY_PATH : ${
      lib.makeLibraryPath [
        zlib
        stdenv.cc.cc.lib
        libpulseaudio
        pipewire
      ]
    }"}

    runHook postInstall
  '';

  # Re-sign the bun-compiled binary after fixup. fixDarwinDylibNames may run
  # install_name_tool, and Bun can produce invalid signatures on newer macOS.
  postFixup = lib.optionalString stdenv.hostPlatform.isDarwin ''
    ${lib.getExe rcodesign} sign --code-signature-flags linker-signed $out/lib/omp/omp
  '';

  # Workers and the stats dashboard only fail at runtime when their bunfs
  # entrypoints are missing; the smoke test catches that at build time.
  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck
    HOME=$TMPDIR $out/bin/omp --smoke-test | grep -q "smoke-test: ok"
    BUN_BE_BUN=1 $out/lib/omp/omp -e \
      'if (Bun.version !== "${bunRuntimeVersion}" || typeof Bun.Image !== "function") process.exit(1)'
    runHook postInstallCheck
  '';

  passthru.category = "AI Coding Agents";

  meta = with lib; {
    description = "A terminal-based coding agent with multi-model support";
    homepage = "https://github.com/can1357/oh-my-pi";
    changelog = "https://github.com/can1357/oh-my-pi/releases/tag/v${version}";
    license = licenses.mit;
    sourceProvenance = with lib.sourceTypes; [ fromSource ];
    maintainers = with maintainers; [ aldoborrero ];
    mainProgram = "omp";
    platforms = builtins.attrNames platformsBySystem;
  };
}
