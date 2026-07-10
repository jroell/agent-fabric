#!/usr/bin/env bash
# install.sh — set up agent-fabric in one command.
#
#   curl -fsSL https://raw.githubusercontent.com/jroell/agent-fabric/main/install.sh | bash
#     — or —
#   git clone https://github.com/jroell/agent-fabric && cd agent-fabric && ./install.sh
#
# What it does (idempotent; safe to re-run):
#   1. Creates the hub at ~/.agent-fabric (skills/, memory/, bin/, .backups/)
#   2. Seeds the canonical AGENTS.md from your existing instructions if you have
#      any (~/.claude/CLAUDE.md, ~/CLAUDE.md, or ~/AGENTS.md), else from a starter template
#   3. Installs the `fabric` CLI and the agent-fabric starter skill into the hub
#   4. Runs `fabric sync` (wires every detected harness) and `fabric verify`
#
# Any real file replaced by a symlink is backed up first to ~/.agent-fabric/.backups/<date>/.
#
# macOS ONLY. Tested on Apple Silicon, macOS 13+.

set -euo pipefail

REPO_URL="https://github.com/jroell/agent-fabric"
FABRIC_HOME_WAS_SET="${FABRIC_HOME+yes}"
FABRIC_HOME="${FABRIC_HOME:-$HOME/.agent-fabric}"

log() { printf '\033[1;34m[install]\033[0m %s\n' "$*"; }
die() { printf '\033[0;31m[install] ERROR: %s\033[0m\n' "$*" >&2; exit 1; }

# ── Options ───────────────────────────────────────────────────────────────────────────────
#   --adopt [PATH]   Adopt an existing hand-rolled hub IN PLACE instead of creating a
#                    new one. PATH defaults to ~/.shared-agent-memory. The hub must
#                    already have an AGENTS.md at its root; skills/ is created if
#                    missing. Curl-pipe form: curl ... | bash -s -- --adopt
ADOPT=0
ADOPT_PATH=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --adopt)
      ADOPT=1
      if [[ -n "${2:-}" && "${2:0:2}" != "--" ]]; then ADOPT_PATH="$2"; shift; fi
      ;;
    -h|--help)
      sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *) die "unknown option: $1 (supported: --adopt [PATH])" ;;
  esac
  shift
done

if [[ "$ADOPT" == "1" ]]; then
  ADOPT_PATH="${ADOPT_PATH:-$HOME/.shared-agent-memory}"
  [[ -d "$ADOPT_PATH" ]] || die "--adopt: $ADOPT_PATH does not exist"
  [[ -f "$ADOPT_PATH/AGENTS.md" && ! -L "$ADOPT_PATH/AGENTS.md" ]] \
    || die "--adopt: $ADOPT_PATH/AGENTS.md must exist as a real file (hub layout: AGENTS.md + skills/ at root)"
  FABRIC_HOME="$ADOPT_PATH"
  FABRIC_HOME_WAS_SET="yes"
  log "adopting existing hub at $FABRIC_HOME (content preserved; fabric CLI + starter skill added)"
fi

# ── 0. Platform guard ──────────────────────────────────────────────────────────────────
[[ "$(uname -s)" == "Darwin" ]] || die "agent-fabric currently supports macOS only (see README)."

# ── 0.5 Competing-hub guard ────────────────────────────────────────────────────────
# If this machine already runs a fabric-style canonical hub (a hand-rolled
# ~/.shared-agent-memory), seeding a second hub would create two competing
# sources of truth fighting over the same symlink surfaces. Adoption must be
# an explicit decision, not a default.
if [[ -d "$HOME/.shared-agent-memory" && "$FABRIC_HOME_WAS_SET" != "yes" ]]; then
  printf '\033[0;31m[install] ERROR: existing canonical hub detected at ~/.shared-agent-memory.\033[0m\n' >&2
  printf 'Installing with defaults would create a SECOND hub competing over the same\n' >&2
  printf 'instruction files and skill directories. Choose one explicitly:\n' >&2
  printf '  * Adopt your existing hub in place:  ./install.sh --adopt\n' >&2
  printf '    (validates layout, keeps your AGENTS.md/skills, adds the fabric CLI)\n' >&2
  printf '  * Force a fresh fabric hub: FABRIC_HOME="$HOME/.agent-fabric" ./install.sh\n' >&2
  printf '    (then migrate content and retire the old hub yourself)\n' >&2
  exit 1
fi

# ── 1. Locate repo files (or fetch them when piped via curl) ────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" 2>/dev/null && pwd || true)"
if [[ -z "$SCRIPT_DIR" || ! -f "$SCRIPT_DIR/bin/fabric" ]]; then
  command -v git >/dev/null 2>&1 || die "git is required (xcode-select --install)"
  TMP_CLONE="$(mktemp -d)"
  log "fetching agent-fabric -> $TMP_CLONE"
  git clone --depth 1 "$REPO_URL" "$TMP_CLONE/agent-fabric" >/dev/null 2>&1 \
    || die "could not clone $REPO_URL"
  SCRIPT_DIR="$TMP_CLONE/agent-fabric"
fi
[[ -f "$SCRIPT_DIR/bin/fabric" ]] || die "repo files not found at $SCRIPT_DIR"

# ── 2. Create the hub ────────────────────────────────────────────────────────
log "creating hub at $FABRIC_HOME"
mkdir -p "$FABRIC_HOME/skills" "$FABRIC_HOME/memory" "$FABRIC_HOME/bin" "$FABRIC_HOME/.backups"

# ── 3. Seed canonical AGENTS.md ──────────────────────────────────────────────
CANONICAL="$FABRIC_HOME/AGENTS.md"
if [[ ! -f "$CANONICAL" ]]; then
  SEEDED=""
  for candidate in "$HOME/.claude/CLAUDE.md" "$HOME/CLAUDE.md" "$HOME/AGENTS.md"; do
    # Seed only from a REAL file (not a symlink — a symlink means some other
    # system already manages it; we don't want to inherit a pointer).
    if [[ -f "$candidate" && ! -L "$candidate" && -s "$candidate" ]]; then
      cp "$candidate" "$CANONICAL"
      SEEDED="$candidate"
      break
    fi
  done
  if [[ -n "$SEEDED" ]]; then
    log "seeded canonical AGENTS.md from your existing $SEEDED"
  else
    cp "$SCRIPT_DIR/templates/AGENTS.md" "$CANONICAL"
    log "seeded canonical AGENTS.md from starter template"
  fi
else
  log "canonical AGENTS.md already exists — leaving it alone"
fi

# ── 4. Install CLI + starter skill ───────────────────────────────────────────
cp "$SCRIPT_DIR/bin/fabric" "$FABRIC_HOME/bin/fabric"
chmod +x "$FABRIC_HOME/bin/fabric"
# Bake the resolved hub path into the installed CLI so adopted/custom hubs work
# without requiring FABRIC_HOME to be exported in every future shell.
sed -i '' "s|^FABRIC_HOME=.*|FABRIC_HOME=\"\${FABRIC_HOME:-${FABRIC_HOME}}\"|" "$FABRIC_HOME/bin/fabric"

if [[ ! -e "$FABRIC_HOME/skills/agent-fabric" ]]; then
  cp -R "$SCRIPT_DIR/templates/skills/agent-fabric" "$FABRIC_HOME/skills/agent-fabric"
  log "installed the agent-fabric starter skill (teaches your agents to operate the fabric)"
fi

# ── 5. Wire everything + verify ──────────────────────────────────────────────
"$FABRIC_HOME/bin/fabric" sync
"$FABRIC_HOME/bin/fabric" verify

echo
log "done. Useful next steps:"
echo "  1. Put the CLI on your PATH:  echo 'export PATH=\"\$HOME/.agent-fabric/bin:\$PATH\"' >> ~/.zshrc"
echo "  2. Edit your canonical rules: \$EDITOR ~/.agent-fabric/AGENTS.md   (every agent sees it instantly)"
echo "  3. Add a skill for all agents: fabric add-skill my-skill"
echo "  4. Adopt an existing skill:    fabric adopt ~/.claude/skills/<name>"
echo "  5. Health check any time:      fabric verify"
echo
echo "  Note: Warp's global Rules live in Warp cloud settings (Settings -> Rules) and"
echo "  can't be wired by file; Warp still picks up all fabric skills via ~/.agents/skills."
