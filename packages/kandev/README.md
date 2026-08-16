# Kandev

Kandev manages its built-in agent runtimes according to each upstream
integration. Managed npm profiles keep using Kandev's `npx` execution paths;
native ACP profiles run their packaged CLI directly.

## Local runtime packages

Agent support flags add known CLIs to the local runtime `PATH`. They are opt-in
so the default package remains independent of every provider:

```nix
kandev.override {
  claudeSupport = true;
  codexSupport = true;
  geminiSupport = true;
  piSupport = true;
  ompSupport = true;
  opencodeSupport = true;
  copilotSupport = true;
  hermesSupport = true;
  ampSupport = true;
  cursorSupport = true;
  droidSupport = true;
  grokSupport = true;
  kilocodeSupport = true;
  kimiSupport = true;
  qoderSupport = true;
  qwenSupport = true;
}
```

The flags control executable availability, not Kandev's agent registry or the
profile selected for a task. Their exact role follows the built-in integration:
managed npm agents use the CLI for discovery, login, or passthrough while native
agents use it as their ACP runtime. Claude support also points
`claude-agent-acp` at the Nix-packaged executable instead of its incompatible
bundled binary on NixOS.

## Custom TUI agents and tools

`extraPackages` adds arbitrary executables to the same runtime `PATH`:

```nix
kandev.override {
  extraPackages = [
    pkgs.gh
    pkgs.my-custom-agent
  ];
}
```

This supports **Settings > Agents > Add TUI Agent**, where Kandev looks up the
registered binary name on `PATH`. Register a stable bare command such as
`my-custom-agent`, not a versioned Nix store path. Adding a package does not
create or configure an agent; the Kandev UI still owns its display name,
command, static `{{model}}` substitution, and optional MCP strategy.

These packages affect Local and Worktree execution on the Kandev host. Docker
images and SSH hosts need their own executable and credential provisioning.
