---
name: agent-fabric
description: >-
  Operate, audit, repair, and extend the agent-fabric on this machine — the canonical
  hub (~/.agent-fabric) that shares skills, rules/instructions, and memory across ALL
  agent harnesses (Claude Code, Codex, Warp, Cursor, Gemini CLI, Grok CLI, OpenCode,
  Hermes).
  Use when the user asks to "audit my agent setup", "sync my agents", "add this
  skill/rule to all agents", "install a skill everywhere", "wire up a new agent",
  "share skills between agents", mentions agent-fabric / canonical skills / shared
  memory, or when a skill or agent config seems broken after a migration or install.
  ALSO USE BEFORE running any migration, conversion, or bulk-install tool that writes
  to skill directories or agent config files, and AFTER such a tool runs.
---

# agent-fabric — canonical cross-agent skills/rules/memory

One source of truth, every harness wired to it by symlink, one idempotent sync, one
verifier. Read this before touching skill dirs, instruction files, or agent configs.
The #1 job: **do the right thing without breaking the other agents.**

## Topology

```
~/.agent-fabric/AGENTS.md        ← canonical rules (real file; edit HERE)
~/.agent-fabric/skills/<name>/   ← canonical skills (real dirs; edit HERE)
~/.agent-fabric/memory/          ← durable notes/facts agents should keep
        ↑ symlinked from
~/AGENTS.md, ~/.claude/CLAUDE.md, ~/.codex/AGENTS.md, ~/.cursor/AGENTS.md,
~/.gemini/GEMINI.md, ~/.grok/AGENTS.md, ~/.config/opencode/AGENTS.md,
~/.hermes/memories/AGENTS.md                                           (instructions)
~/.agents/skills, ~/.claude/skills, ~/.codex/skills, ~/.grok/skills,
~/.config/opencode/skills, ~/.hermes/skills                            (skills, additive)
```

## Golden rules

1. **NEVER write "through" a symlinked path.** `~/.claude/skills/x/SKILL.md` may resolve
   to `~/.agent-fabric/skills/x/SKILL.md`. Writing to a fanout path edits the canonical
   file for EVERY agent. Run `readlink -f <path>` before writing and decide consciously.
2. **Migration/conversion/bulk-install tools go to scratch dirs, never fanout surfaces.**
   Naive YAML rewriters destroy folded frontmatter (`description: >-` becomes the literal
   string `">-"`), silently killing skill triggering in every harness. Run such tools
   into a temp dir, diff, then copy intentionally.
3. **Merge configs, never replace wholesale.** Back up first (`cp config config.bak-<date>`).
4. **Skill fanout is additive.** Existing real dirs in a harness's skills folder are never
   replaced. If a skill should be shared, `fabric adopt <dir>` moves it into the hub.
5. **Secrets never go inline in configs.** Use each tool's env-var indirection.
6. **Warp exception:** Warp's global Rules live in its cloud settings, not `~/.warp/AGENTS.md`.
   Warp still discovers all fabric skills via `~/.agents/skills`.
7. **Gemini CLI reads `~/.gemini/GEMINI.md`**, not AGENTS.md; the fabric wires that path.
8. **Hermes exceptions:** in `~/.hermes/memories/` only `AGENTS.md` may be a symlink —
   Hermes's memory-repair de-symlinks `MEMORY.md`/`USER.md` and rewrites them as real files.
   Hermes's curator may archive unused fabric skill links to `~/.hermes/skills/.archive/`
   (`hermes curator restore <name>` recovers them; the hub copy is never affected).
9. **Fix the tooling, not the symptom.** If wiring is wrong, fix it via `fabric sync`
   (or improve the fabric scripts) rather than hand-crafting one-off symlinks.

## Commands (idempotent; end every fabric change with verify or doctor)

```bash
~/.agent-fabric/bin/fabric sync            # wire instructions + fan out skills
~/.agent-fabric/bin/fabric sync --dry-run  # preview changes without writing — USE THIS FIRST
~/.agent-fabric/bin/fabric verify          # topology + skill integrity; exit 1 on drift
~/.agent-fabric/bin/fabric doctor          # effective-loading probes (stale copies, @-imports)
~/.agent-fabric/bin/fabric status --json   # machine-readable harness/wiring state
~/.agent-fabric/bin/fabric add-skill <name>
~/.agent-fabric/bin/fabric adopt <existing-skill-dir>
```

When making risky or bulk changes, run `sync --dry-run` first and `doctor` after — doctor
catches what topology checks miss (stale copies that used to be symlinks, broken overlays).

## Playbooks

- **Audit**: `fabric verify`. Then, after any suspicious tool run:
  `find ~/.agent-fabric/skills -name SKILL.md -newermt '<tool run time>'` — files you
  didn't intentionally edit are casualties.
- **Add a rule for every agent**: edit `~/.agent-fabric/AGENTS.md` directly.
- **Add a skill for every agent**: `fabric add-skill <name>`, edit the generated SKILL.md.
- **Share an existing per-tool skill**: `fabric adopt <path-to-skill-dir>`.
- **Repair corruption**: restore from `~/.agent-fabric/.backups/<date>/`, check git if the
  skill dir is a repo, then `fabric sync && fabric verify`.
