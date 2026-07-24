{
  lib,
  buildNpmPackage,
  fetchFromGitHub,
  makeWrapper,
  claude-code,
}:

buildNpmPackage rec {
  npmDepsFetcherVersion = 2;
  pname = "claude-agent-acp";
  version = "0.62.0";

  src = fetchFromGitHub {
    owner = "agentclientprotocol";
    repo = "claude-agent-acp";
    tag = "v${version}";
    hash = "sha256-MF/gzEr3z64tRd+2TX36/VAHSPYJzYU5+1qR9OEu97Q=";
  };

  npmDepsHash = "sha256-MeIbE7qsuC1+dhsAGV6rPlM+PrrRbT2VEsehRKTgV+c=";
  makeCacheWritable = true;

  # Disable install scripts to avoid platform-specific dependency fetching issues
  npmFlags = [ "--ignore-scripts" ];

  nativeBuildInputs = [ makeWrapper ];

  # The bundled @anthropic-ai/claude-agent-sdk platform packages ship a
  # prebuilt dynamically linked `claude` binary that is not usable on NixOS;
  # point the adapter at this flake's claude-code package instead, unless the
  # user overrides CLAUDE_CODE_EXECUTABLE themselves.
  postInstall = ''
    wrapProgram $out/bin/claude-agent-acp \
      --set-default CLAUDE_CODE_EXECUTABLE ${lib.getExe claude-code}
  '';

  passthru.category = "ACP Ecosystem";

  meta = with lib; {
    description = "An ACP-compatible coding agent powered by the Claude Code SDK (TypeScript)";
    homepage = "https://github.com/agentclientprotocol/claude-agent-acp";
    changelog = "https://github.com/agentclientprotocol/claude-agent-acp/releases/tag/v${version}";
    license = licenses.asl20;
    sourceProvenance = with sourceTypes; [ fromSource ];
    maintainers = with maintainers; [ ];
    mainProgram = "claude-agent-acp";
    platforms = platforms.all;
  };
}
