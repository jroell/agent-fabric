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
| everything else | `~/AGENTS.md` → hub | `~/.agents/skills/*` (additive) |

¹ Warp's *global* Rules live in Warp's cloud settings (Settings → Rules) and can't be wired
by file — paste your AGENTS.md highlights there once. Warp *does* automatically discover all
fabric skills through `~/.agents/skills`.

**Additive** means the fabric never replaces an existing real skill in a harness's skill
folder — your per-tool skills and vendor-bundled skills survive untouched.

## Daily use

```bash
fabric add-skill code-review     # scaffold a skill; instantly available to every agent
fabric adopt ~/.claude/skills/x  # promote an existing per-tool skill to all agents
$EDITOR ~/.agent-fabric/AGENTS.md   # edit rules once, all agents see it
fabric verify                    # health check — exits 1 on any drift or corruption
fabric status                    # which harnesses are detected and wired
fabric sync                      # re-wire (idempotent; run after installing a new agent)
```

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
- Linux support
- More harnesses (Hermes, ForgeCode, Antigravity, gitgang)

## License

MIT
