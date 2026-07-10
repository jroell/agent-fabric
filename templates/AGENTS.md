# AGENTS.md — Canonical Instructions

> This is the single source of truth for ALL AI coding agents on this machine
> (Claude Code, Codex, Warp, Cursor, Gemini CLI, Grok CLI, OpenCode, ...).
> It lives at `~/.agent-fabric/AGENTS.md` and is symlinked into every tool's
> instruction path. Edit it here — every agent sees the change instantly.

## About me

- Name: <your name>
- Role: <what you do>
- Timezone / working hours: <optional>

## Communication style

- Be concise and direct. No filler.
- Never claim authorship on my behalf in commits, PRs, or tickets unless asked.

## Coding conventions

- <e.g. formatter/linter of choice, test framework, commit message style>

## Hard rules

- Never commit or push without being asked.
- Never store secrets in config files — use environment variables or a secret manager.
- When editing skills or agent configs, remember: many paths on this machine are
  symlinks into `~/.agent-fabric/`. Check with `readlink -f` before writing.

## Projects

- <project name>: <one-line description, repo path, key commands>
