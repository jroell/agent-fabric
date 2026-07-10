# agent-fabric

**One canonical home for your AI agents' skills, rules, and memory — shared across every
agent harness on your Mac.**

Install a skill once, every agent can use it. Write a rule once, every agent follows it.
Claude Code, Codex, Warp, Cursor, Gemini CLI, Grok CLI, and OpenCode all read from a single
source of truth, wired together with symlinks and kept honest by a verifier.

> ## ⚠️ macOS only (for now)
> This project currently targets **macOS on Apple Silicon (macOS 13+)** and assumes the
> default BSD userland and zsh/bash 3.2 environment that ships with it. It is developed
> and tested on that setup. Linux/Windows are not supported yet — PRs welcome.

## The problem

Every AI coding agent invents its own config surface: Claude Code reads `~/.claude/CLAUDE.md`
and `~/.claude/skills/`, Codex reads `~/.codex/AGENTS.md`, Gemini CLI reads `~/.gemini/GEMINI.md`,
Warp scans `~/.agents/skills/`, and so on. If you use more than one agent, your rules drift,
your skills fragment, and each tool knows a different version of you.

## The fix

A single hub — `~/.agent-fabric/` — holds the canonical copy of everything. Every harness
gets a **symlink**, never a copy. Edit one file; every agent sees it instantly.

```
~/.agent-fabric/
├── AGENTS.md          ← your canonical rules (ONE file, every agent reads it)
├── skills/<name>/     ← your canonical skills (ONE dir per skill, every agent sees them)
├── memory/            ← durable notes you want agents to keep
├── bin/fabric         ← the CLI (sync / verify / status / add-skill / adopt)
└── .backups/<date>/   ← automatic backups of anything the fabric ever replaced
```

## Quickstart

```bash
curl -fsSL https://raw.githubusercontent.com/jroell/agent-fabric/main/install.sh | bash
```

or:

```bash
git clone https://github.com/jroell/agent-fabric && cd agent-fabric && ./install.sh
```

The installer:

1. Creates the hub at `~/.agent-fabric/`
2. **Seeds your canonical AGENTS.md from your existing instructions** if you have any
   (`~/.claude/CLAUDE.md`, `~/CLAUDE.md`, or `~/AGENTS.md`) — else from a starter template
3. Wires every **detected** harness (it never creates config dirs for tools you don't use)
4. Backs up any real file before replacing it with a symlink
5. Runs the verifier and prints next steps

It is idempotent — re-run it any time.

### Already have a hand-rolled hub?

If the installer detects an existing `~/.shared-agent-memory` hub it will refuse to create
a second source of truth. Adopt your existing hub in place instead — content is preserved,
the `fabric` CLI and starter skill are added, and every harness gets wired to *your* hub:

```bash
./install.sh --adopt                 # adopts ~/.shared-agent-memory
./install.sh --adopt /path/to/hub    # adopts a custom hub location
# curl-pipe form:
curl -fsSL https://raw.githubusercontent.com/jroell/agent-fabric/main/install.sh | bash -s -- --adopt
```

The hub must have an `AGENTS.md` at its root; `skills/` is created if missing. The installed
CLI bakes in your hub path, so `FABRIC_HOME` never needs to be exported.

## What gets wired

| Harness | Instructions | Skills |
|---|---|---|
| Claude Code | `~/.claude/CLAUDE.md` → hub | `~/.claude/skills/*` (additive) |
| Codex | `~/.codex/AGENTS.md` → hub | `~/.codex/skills/*` (additive) |
| Warp | see note ¹ | `~/.agents/skills/*` (additive) |
| Cursor | `~/.cursor/AGENTS.md` → hub | via `~/.agents/skills` |
| Gemini CLI | `~/.gemini/GEMINI.md` → hub | (no skills system) |
| Grok CLI | `~/.grok/AGENTS.md` → hub | `~/.grok/skills/*` (additive) |
| OpenCode | `~/.config/opencode/AGENTS.md` → hub | `~/.config/opencode/skills/*` (additive) |
| Hermes | `~/.hermes/memories/AGENTS.md` → hub | `~/.hermes/skills/*` (additive) ² |
| everything else | `~/AGENTS.md` → hub | `~/.agents/skills/*` (additive) |

¹ Warp's *global* Rules live in Warp's cloud settings (Settings → Rules) and can't be wired
by file — paste your AGENTS.md highlights there once. Warp *does* automatically discover all
fabric skills through `~/.agents/skills`.

² Hermes organizes its own skills into domain folders (e.g. `github/`, `creative/`); fabric
skills are added as flat top-level dirs alongside them, which Hermes also discovers. Its
native memory system keeps working — the fabric only adds the shared instruction layer.
This wiring pattern has been validated against a live, long-running Hermes installation.
Known Hermes edge cases:

- **Only `AGENTS.md` is safe to symlink in `~/.hermes/memories/`.** Hermes owns the other
  files there (`MEMORY.md`, `USER.md`, locks) and its memory-repair mechanism will detect a
  symlinked `MEMORY.md`, back the symlink up, and replace it with a real file. The fabric
  deliberately wires only `AGENTS.md`, which repair leaves alone — don't hand-link the rest.
- **Hermes's curator archives stale skills.** Skills unused for long enough get moved to
  `~/.hermes/skills/.archive/` (recoverable with `hermes curator restore <name>`). If a
  fabric skill gets archived, the next `fabric sync` will re-link it — so a skill Hermes
  never uses may bounce between archived and re-linked. Harmless (the hub copy is never
  affected), but if you want Hermes to stop seeing a fabric skill permanently, remove its
  symlink from `~/.hermes/skills/` — note the next `fabric sync` will restore it.
- **Fresh installs:** `~/.hermes/memories/` may not exist until Hermes first runs; the
  fabric creates it when wiring, and Hermes adopts the directory normally afterwards.

**Additive** means the fabric never replaces an existing real skill in a harness's skill
folder — your per-tool skills and vendor-bundled skills survive untouched.

## Daily use

```bash
fabric add-skill code-review     # scaffold a skill; instantly available to every agent
fabric adopt ~/.claude/skills/x  # promote an existing per-tool skill to all agents
$EDITOR ~/.agent-fabric/AGENTS.md   # edit rules once, all agents see it
fabric verify                    # topology + integrity check — exits 1 on drift/corruption
fabric doctor                    # effective-loading probes: does each harness actually
                                 #   resolve canonical content? catches stale copies and
                                 #   validates @-import overlays; reports Warp as manual
fabric status                    # which harnesses are detected, their strategies + state
fabric status --json             # same, machine-readable (for scripts/CI/backup jobs)
fabric sync                      # re-wire (idempotent; run after installing a new agent)
fabric sync --dry-run            # preview exactly what sync would change, write nothing
```

Every harness is described by a **registry** in `bin/fabric` recording its detection dir,
instruction path + strategy (`symlink` or `manual`), skills dir + strategy (`additive` or
`none`), and CLI name for probes — adding a harness is one registry line.

### Worked examples

**Preview before you touch anything** — `sync --dry-run` prints every action it *would*
take (links, backups) and writes nothing:

```text
$ fabric sync --dry-run
[fabric] DRY RUN — no changes will be written
[fabric] wiring instruction files
[fabric] [dry-run] would link ~/.codex/AGENTS.md -> ~/.agent-fabric/AGENTS.md
[fabric] fanning out skills (additive)
[fabric] sync done
```

**Script against the fabric** — `status --json` is stable, parseable output:

```text
$ fabric status --json | python3 -m json.tool
{
  "fabric_home": "/Users/you/.agent-fabric",
  "skill_count": 3,
  "skills": ["agent-fabric", "code-review", "team-conventions"],
  "harnesses": [
    {"name": "codex", "detected": true,
     "instructions": {"path": "/Users/you/.codex/AGENTS.md", "strategy": "symlink", "state": "wired"},
     "skills": {"path": "/Users/you/.codex/skills", "strategy": "additive", "linked": 3}},
    {"name": "warp", "detected": true,
     "instructions": {"strategy": "manual", "state": "manual"},
     "note": "Warp global Rules are cloud-managed (Settings -> Rules); skills discovered via ~/.agents/skills"}
  ]
}
```

States: `wired` (symlink to canonical) · `conflict` (something else occupies the path —
run `fabric sync`) · `missing` · `manual` (cannot be file-wired; do it in the tool's UI) ·
`not-detected` (tool not installed).

**Prove the content actually loads** — `doctor` catches what topology checks can't name.
For example, if a symlink was replaced by an edited copy at some point:

```text
$ fabric doctor
[PASS] canonical resolves and is non-empty
[FAIL] codex: ~/.codex/AGENTS.md does NOT resolve to canonical (stale or divergent content)
[info] warp: MANUAL/unverifiable — Warp global Rules are cloud-managed (Settings -> Rules); ...
1 doctor probe(s) failed.
$ fabric sync && fabric doctor   # repair, then re-probe
All doctor probes passed.
```

`doctor` also accepts the **overlay pattern**: if an instruction path is a real file that
contains a genuine `@`-import of the canonical AGENTS.md (Claude Code syntax), that passes —
a file that merely *mentions* the canonical path does not.

Put it on your PATH: `echo 'export PATH="$HOME/.agent-fabric/bin:$PATH"' >> ~/.zshrc`

A starter skill (`agent-fabric`) is installed into the hub. It teaches your agents how the
fabric works, so any agent asked to "add a skill for all my agents" or "audit my agent setup"
does the right thing — and doesn't break the other agents.

## Golden rules (learned from real incidents)

1. **Never write "through" a symlink by accident.** A path like `~/.claude/skills/x/SKILL.md`
   may resolve into the hub — writing there edits the file for *every* agent. `readlink -f`
   first.
2. **Point migration/conversion tools at scratch dirs, never at live agent dirs.** Naive
   YAML rewriters have destroyed skill frontmatter across an entire machine by writing
   through symlink fanout.
3. **Merge configs; never replace them wholesale.** The fabric backs up anything it replaces
   to `~/.agent-fabric/.backups/<date>/`.
4. **Secrets never go inline in configs.** Use each tool's env-var indirection.
5. **End every change with `fabric verify`.** It catches broken links, missing frontmatter,
   and known corruption signatures.

## Tests

```bash
bash tests/run-tests.sh
```

Everything runs in a throwaway sandbox `$HOME` (created with `mktemp`) — the suite simulates
a machine with several harnesses and pre-existing content, then asserts install, seeding,
wiring, backups, additive safety, idempotency, `add-skill`, `adopt`, and corruption
detection. Your real home directory is never touched. CI runs the same suite on
`macos-latest`.

## Uninstall

```bash
# Remove the symlinks the fabric created, restoring your backups:
ls ~/.agent-fabric/.backups/            # find your original files
# For each symlink you want to undo:
rm <symlink> && cp -R ~/.agent-fabric/.backups/<date>/<backup> <original-path>
rm -rf ~/.agent-fabric                  # remove the hub last
```

## Roadmap

- Optional shared adaptive memory via [Mem0](https://mem0.ai) MCP (config snippets per tool)
- Deep runtime probes in `fabric doctor` (invoke each harness's own diagnostics — e.g.
  `grok inspect`, `hermes doctor` — where versions support it non-interactively)
- Linux support
- More harnesses (ForgeCode, Antigravity, gitgang)

## License

MIT
