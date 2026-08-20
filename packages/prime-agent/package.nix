{
  lib,
  buildNpmPackage,
  cairo,
  fetchFromGitHub,
  flake,
  giflib,
  libjpeg,
  librsvg,
  makeWrapper,
  nodejs_22,
  pango,
  pixman,
  pkg-config,
  python3,
  versionCheckHook,
  versionCheckHomeHook,
}:

let
  # prime-agent-runtime 0.8.0 requires mcp>=2,<3 and nixpkgs still ships 1.29.0.
  # Build the 2.0.0 SDK and its newly split-out mcp-types wire package from the
  # one upstream tag, behind an overridden Python package set so the runtime,
  # the bundled skills, and the kernel environment all resolve the same mcp.
  # Drop this block once nixpkgs carries mcp 2.x.
  mcpVersion = "2.0.0";

  mcpSrc = fetchFromGitHub {
    owner = "modelcontextprotocol";
    repo = "python-sdk";
    tag = "v${mcpVersion}";
    hash = "sha256-baeceVB9PC+f3vQO1AaDHflOJ7oD7u7ylXUkVvusT/o=";
  };

  python = python3.override {
    self = python;
    packageOverrides = final: prev: {
      mcp-types = prev.buildPythonPackage {
        pname = "mcp-types";
        version = mcpVersion;
        pyproject = true;
        src = "${mcpSrc}/src/mcp-types";

        # uv-dynamic-versioning reads the version out of git history, which a
        # source archive does not carry.
        env.UV_DYNAMIC_VERSIONING_BYPASS = mcpVersion;

        build-system = [
          prev.hatchling
          prev.uv-dynamic-versioning
        ];

        dependencies = [
          prev.pydantic
          prev.typing-extensions
        ];

        pythonImportsCheck = [ "mcp_types" ];
      };

      mcp = prev.mcp.overridePythonAttrs (old: {
        version = mcpVersion;
        src = mcpSrc;

        env = (old.env or { }) // {
          UV_DYNAMIC_VERSIONING_BYPASS = mcpVersion;
        };

        # The 1.x darwin flake patch targets a test file 2.0.0 no longer ships.
        postPatch = "";

        # 2.0.0 dropped pydantic-settings, httpx and httpx-sse for httpx2, and
        # split its wire types into mcp-types.
        pythonRelaxDeps = [ ];
        dependencies = [
          prev.anyio
          prev.httpx2
          prev.jsonschema
          prev.opentelemetry-api
          prev.pydantic
          prev.pyjwt
          prev.python-multipart
          prev.sse-starlette
          prev.starlette
          prev.typing-extensions
          prev.typing-inspection
          prev.uvicorn
          final.mcp-types
        ];

        optional-dependencies = {
          cli = [
            prev.python-dotenv
            prev.typer
          ];
          rich = [ prev.rich ];
        };

        # The 1.x disabledTests list is written against a suite 2.0.0 reorganized.
        doCheck = false;
        nativeCheckInputs = [ ];
        disabledTests = [ ];
      });
    };
  };
in

buildNpmPackage (finalAttrs: {
  npmDepsFetcherVersion = 2;
  pname = "prime-agent";
  version = "0.8.0";

  src = fetchFromGitHub {
    owner = "PrimeIntellect-ai";
    repo = "prime-agent";
    tag = "v${finalAttrs.version}";
    hash = "sha256-9XOGeZMjAWeoD1vo/4LkuKHNtBawGri/2kcKIZ99Xms=";
  };

  nodejs = nodejs_22;
  npmDepsHash = "sha256-DDRh4iMIQ8HGLVPdav2+4ONwxhlMt7kYCXE4h/OGhxQ=";

  nativeBuildInputs = [
    makeWrapper
    pkg-config
  ];

  buildInputs = [
    cairo
    giflib
    libjpeg
    librsvg
    pango
    pixman
  ];

  # npm 11 omits registry metadata for duplicated transitive package versions.
  # fetchNpmDeps needs that metadata to cache every version for offline npm ci.
  postPatch = ''
    cp ${./package-lock.json} package-lock.json

    # Release tags include generated model data. Regenerating it would access
    # several model catalog APIs during the sandboxed build.
    substituteInPlace packages/ai/package.json \
      --replace-fail 'npm run generate-models && tsgo' 'tsgo'

    # nix develop uses a long per-shell TMPDIR on Darwin. Worker socket paths
    # then exceed sockaddr_un.sun_path and Node creates a truncated socket that
    # Prime Agent cannot find. Keep daemon sockets in the short runtime dir.
    substituteInPlace packages/coding-agent/src/modes/daemon/daemon-socket.ts \
      --replace-fail \
        'return join(tmpdir(), `prime-agent-''${suffix}`);' \
        'return join(process.env.XDG_RUNTIME_DIR || "/tmp", `prime-agent-''${suffix}`);'
  '';

  installPhase = ''
    runHook preInstall

    npm prune --omit=dev

    mkdir -p $out/lib/prime-agent $out/bin
    cp -r node_modules $out/lib/prime-agent/
    cp -r packages $out/lib/prime-agent/

    makeWrapper ${lib.getExe nodejs_22} $out/bin/prime-agent \
      --add-flags "$out/lib/prime-agent/packages/coding-agent/dist/bundle/cli.js" \
      --set PI_PACKAGE_DIR "$out/lib/prime-agent/packages/coding-agent" \
      --set PRIME_AGENT_KERNEL_PYTHON ${finalAttrs.passthru.pythonRuntime}/bin/python3

    runHook postInstall
  '';

  doInstallCheck = true;
  nativeInstallCheckInputs = [
    versionCheckHook
    versionCheckHomeHook
  ];

  postInstallCheck = ''
    ${finalAttrs.passthru.pythonRuntime}/bin/python3 <<'PY'
    import agent_message, agent_observe, attach_image, compact, edit, goal
    import dill, ipykernel, linear, notion, refine, rlm, rlm_heartbeat, websearch

    assert callable(rlm.run)
    assert callable(rlm.host_request)
    assert callable(refine.run)
    assert callable(refine.status)
    PY
  '';

  passthru = {
    category = "AI Coding Agents";

    primeAgentRuntime = python.pkgs.buildPythonPackage {
      pname = "prime-agent-runtime";
      version = "0.1.0";
      src = "${finalAttrs.src}/prime-agent-runtime";
      pyproject = true;
      build-system = [ python.pkgs.hatchling ];
      dependencies = with python.pkgs; [
        ipykernel
        mcp
        nest-asyncio
        tyro
      ];
    };

    pythonSkills =
      let
        buildSkill =
          {
            directory,
            version,
            pname ? directory,
            dependencies ? [ ],
          }:
          python.pkgs.buildPythonPackage {
            inherit pname version dependencies;
            src = "${finalAttrs.src}/packages/coding-agent/skills/${directory}";
            pyproject = true;
            build-system = [ python.pkgs.hatchling ];
          };
        runtime = finalAttrs.passthru.primeAgentRuntime;
      in
      # update.py relies on adjacent directory and version fields to update
      # each bundled skill independently when upstream versions diverge.
      [
        (buildSkill {
          directory = "agent-message";
          version = "0.1.0";
        })
        (buildSkill {
          directory = "agent-observe";
          version = "0.1.0";
        })
        (buildSkill {
          directory = "attach-image";
          version = "0.1.0";
          pname = "prime-agent-skill-attach-image";
          dependencies = with python.pkgs; [
            pillow
            runtime
          ];
        })
        (buildSkill {
          directory = "compact";
          version = "0.1.0";
        })
        (buildSkill {
          directory = "edit";
          version = "0.1.0";
        })
        (buildSkill {
          directory = "goal";
          version = "0.1.0";
        })
        (buildSkill {
          directory = "linear";
          version = "0.1.0";
          pname = "prime-agent-skill-linear";
          dependencies = with python.pkgs; [
            httpx
            mcp
            runtime
          ];
        })
        (buildSkill {
          directory = "notion";
          version = "0.1.0";
          pname = "prime-agent-skill-notion";
          dependencies = with python.pkgs; [
            httpx
            mcp
            runtime
          ];
        })
        (buildSkill {
          directory = "refine";
          version = "0.1.0";
        })
        (buildSkill {
          directory = "rlm-heartbeat";
          version = "0.1.0";
        })
        (buildSkill {
          directory = "websearch";
          version = "0.1.0";
          pname = "prime-agent-skill-websearch";
          dependencies = with python.pkgs; [
            httpx
            runtime
          ];
        })
      ];

    pythonRuntime = python.withPackages (
      ps:
      (with ps; [
        beautifulsoup4
        dill
        httpx
        ipykernel
        ipython
        lxml
        mcp
        nest-asyncio
        numpy
        pandas
        pillow
        pydantic
        python-dotenv
        pyyaml
        requests
        scipy
        tomli
        tyro
      ])
      ++ [ finalAttrs.passthru.primeAgentRuntime ]
      ++ finalAttrs.passthru.pythonSkills
    );
  };

  meta = {
    description = "A self-improving RLM agent for coding workflows and long-running autonomous tasks.";
    homepage = "https://github.com/PrimeIntellect-ai/prime-agent";
    changelog = "https://github.com/PrimeIntellect-ai/prime-agent/releases/tag/v${finalAttrs.version}";
    license = lib.licenses.mit;
    sourceProvenance = with lib.sourceTypes; [ fromSource ];
    maintainers = with flake.lib.maintainers; [ mulatta ];
    mainProgram = "prime-agent";
    platforms = lib.platforms.unix;
  };
})
