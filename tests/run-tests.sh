#!/usr/bin/env bash
# run-tests.sh — sandboxed end-to-end tests for agent-fabric.
#
# SAFETY: every test runs against a throwaway $HOME created with mktemp.
# The real home directory is never read from or written to.
#
# Usage: bash tests/run-tests.sh

set -uo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

PASS=0
FAIL=0
RED=$'\033[0;31m'; GREEN=$'\033[0;32m'; NC=$'\033[0m'

t_pass() { PASS=$((PASS + 1)); printf '%s[PASS]%s %s\n' "$GREEN" "$NC" "$*"; }
t_fail() { FAIL=$((FAIL + 1)); printf '%s[FAIL]%s %s\n' "$RED" "$NC" "$*"; }

assert() { # assert <exit-ok?> <description>
  if [[ "$1" == "0" ]]; then t_pass "$2"; else t_fail "$2"; fi
}

# ── Sandbox setup ─────────────────────────────────────────────────────────────
SANDBOX="$(mktemp -d /tmp/agent-fabric-test.XXXXXX)"
cleanup() { rm -rf "$SANDBOX"; }
trap cleanup EXIT

export HOME="$SANDBOX"
unset FABRIC_HOME  # derive from sandbox HOME
FABRIC_HOME="$HOME/.agent-fabric"
FABRIC="$FABRIC_HOME/bin/fabric"

echo "sandbox HOME: $HOME"
echo

# Simulate a user who already has several harnesses with pre-existing content.
mkdir -p "$HOME/.claude/skills/my-precious-skill" \
         "$HOME/.codex" "$HOME/.grok/skills/xai-bundled" \
         "$HOME/.gemini" "$HOME/.cursor" "$HOME/.warp" \
         "$HOME/.config/opencode" "$HOME/.hermes/skills/github"

cat > "$HOME/.claude/CLAUDE.md" <<'EOF'
# My existing rules
SENTINEL-EXISTING-RULES-42
EOF

cat > "$HOME/.claude/skills/my-precious-skill/SKILL.md" <<'EOF'
---
name: my-precious-skill
description: A user skill that must never be replaced by the fabric.
---
precious content
EOF

cat > "$HOME/.grok/skills/xai-bundled/SKILL.md" <<'EOF'
---
name: xai-bundled
description: Vendor-bundled skill that must survive fanout.
---
vendor content
EOF

# Stale GEMINI.md that should be backed up then replaced with a symlink
echo "old gemini context" > "$HOME/.gemini/GEMINI.md"

# ── Test 1: install ───────────────────────────────────────────────────────────
echo "=== T1: install.sh ==="
bash "$REPO_DIR/install.sh" >/tmp/agent-fabric-test-install.log 2>&1
assert $? "install.sh exits 0 (log: /tmp/agent-fabric-test-install.log)"

[[ -d "$FABRIC_HOME/skills" && -d "$FABRIC_HOME/memory" && -d "$FABRIC_HOME/bin" ]]
assert $? "hub directory structure created"

[[ -x "$FABRIC" ]]
assert $? "fabric CLI installed and executable"

grep -q 'SENTINEL-EXISTING-RULES-42' "$FABRIC_HOME/AGENTS.md"
assert $? "canonical AGENTS.md seeded from existing ~/.claude/CLAUDE.md"

# ── Test 2: instruction symlinks ─────────────────────────────────────────────
echo; echo "=== T2: instruction wiring ==="
for target in "$HOME/AGENTS.md" "$HOME/.claude/CLAUDE.md" "$HOME/.codex/AGENTS.md" \
              "$HOME/.warp/AGENTS.md" "$HOME/.cursor/AGENTS.md" "$HOME/.gemini/GEMINI.md" \
              "$HOME/.grok/AGENTS.md" "$HOME/.config/opencode/AGENTS.md" \
              "$HOME/.hermes/memories/AGENTS.md"; do
  [[ -L "$target" && "$(readlink "$target")" == "$FABRIC_HOME/AGENTS.md" ]]
  assert $? "symlink: $target -> canonical"
done

ls "$FABRIC_HOME/.backups"/*/ 2>/dev/null | grep -q 'CLAUDE.md'
assert $? "pre-existing CLAUDE.md was backed up before replacement"

ls "$FABRIC_HOME/.backups"/*/ 2>/dev/null | grep -q 'GEMINI.md'
assert $? "pre-existing GEMINI.md was backed up before replacement"

# ── Test 3: skill fanout (additive) ──────────────────────────────────────────
echo; echo "=== T3: skill fanout ==="
for dir in "$HOME/.agents/skills" "$HOME/.claude/skills" "$HOME/.codex/skills" \
           "$HOME/.grok/skills" "$HOME/.config/opencode/skills" "$HOME/.hermes/skills"; do
  [[ -L "$dir/agent-fabric" && -f "$dir/agent-fabric/SKILL.md" ]]
  assert $? "starter skill fanned out to $dir"
done

[[ ! -L "$HOME/.claude/skills/my-precious-skill" && -f "$HOME/.claude/skills/my-precious-skill/SKILL.md" ]]
assert $? "pre-existing user skill untouched (still a real dir)"

[[ ! -L "$HOME/.grok/skills/xai-bundled" ]]
assert $? "vendor-bundled grok skill untouched"

[[ -d "$HOME/.hermes/skills/github" && ! -L "$HOME/.hermes/skills/github" ]]
assert $? "hermes domain-taxonomy folder untouched"

# ── Test 4: verify passes on a healthy install ───────────────────────────────
echo; echo "=== T4: verify (healthy) ==="
"$FABRIC" verify >/dev/null 2>&1
assert $? "fabric verify exits 0 after install"

# ── Test 5: idempotency ──────────────────────────────────────────────────────
echo; echo "=== T5: idempotent re-install ==="
before="$(find "$HOME" -type l 2>/dev/null | sort | shasum | awk '{print $1}')"
bash "$REPO_DIR/install.sh" >/dev/null 2>&1
assert $? "second install.sh run exits 0"
after="$(find "$HOME" -type l 2>/dev/null | sort | shasum | awk '{print $1}')"
[[ "$before" == "$after" ]]
assert $? "symlink topology unchanged after re-install"
grep -q 'SENTINEL-EXISTING-RULES-42' "$FABRIC_HOME/AGENTS.md"
assert $? "canonical AGENTS.md not overwritten on re-install"

# ── Test 6: add-skill ────────────────────────────────────────────────────────
echo; echo "=== T6: add-skill ==="
"$FABRIC" add-skill test-skill >/dev/null 2>&1
assert $? "fabric add-skill exits 0"
[[ -f "$FABRIC_HOME/skills/test-skill/SKILL.md" ]]
assert $? "skill created in hub"
[[ -L "$HOME/.claude/skills/test-skill" && -L "$HOME/.codex/skills/test-skill" ]]
assert $? "new skill fanned out to harnesses"
"$FABRIC" verify >/dev/null 2>&1
assert $? "verify still passes after add-skill"

# ── Test 7: adopt ────────────────────────────────────────────────────────────
echo; echo "=== T7: adopt ==="
"$FABRIC" adopt "$HOME/.claude/skills/my-precious-skill" >/dev/null 2>&1
assert $? "fabric adopt exits 0"
[[ -d "$FABRIC_HOME/skills/my-precious-skill" && ! -L "$FABRIC_HOME/skills/my-precious-skill" ]]
assert $? "adopted skill is now canonical in hub"
[[ -L "$HOME/.claude/skills/my-precious-skill" ]]
assert $? "original location is now a symlink to hub"
grep -q 'precious content' "$HOME/.codex/skills/my-precious-skill/SKILL.md"
assert $? "adopted skill visible from other harnesses"

# ── Test 8: corruption detection ─────────────────────────────────────────────
echo; echo "=== T8: corruption detection ==="
mkdir -p "$FABRIC_HOME/skills/corrupted-skill"
cat > "$FABRIC_HOME/skills/corrupted-skill/SKILL.md" <<'EOF'
---
name: corrupted-skill
description: ">-"
---
body
EOF
"$FABRIC" verify >/dev/null 2>&1
[[ $? -ne 0 ]]
assert $? "verify exits non-zero when a skill has the corrupted-description signature"
rm -rf "$FABRIC_HOME/skills/corrupted-skill"
# remove fanned-out links left by nothing (corrupted skill was never synced) and re-verify
"$FABRIC" verify >/dev/null 2>&1
assert $? "verify passes again after removing the corrupted skill"

# ── Test 9: broken symlink detection ─────────────────────────────────────────
echo; echo "=== T9: broken symlink detection ==="
ln -s "$FABRIC_HOME/skills/does-not-exist" "$HOME/.agents/skills/ghost-skill"
"$FABRIC" verify >/dev/null 2>&1
[[ $? -ne 0 ]]
assert $? "verify exits non-zero on broken fanout symlink"
rm "$HOME/.agents/skills/ghost-skill"
"$FABRIC" verify >/dev/null 2>&1
assert $? "verify passes again after removing broken symlink"

# ── Test 10: harness detection (absent harness not wired) ───────────────────
echo; echo "=== T10: absent harness stays absent ==="
[[ ! -e "$HOME/.aider" && ! -e "$HOME/.gitgang" ]]
assert $? "undetected harness dirs were not created by the fabric"

# ── Test 11: competing-hub guard ───────────────────────────────────────
echo; echo "=== T11: competing-hub guard ==="
GUARD_HOME="$(mktemp -d /tmp/agent-fabric-guard.XXXXXX)"
mkdir -p "$GUARD_HOME/.shared-agent-memory"
env -u FABRIC_HOME HOME="$GUARD_HOME" bash "$REPO_DIR/install.sh" >/dev/null 2>&1
[[ $? -ne 0 ]]
assert $? "install refuses to seed a second hub when ~/.shared-agent-memory exists"
[[ ! -e "$GUARD_HOME/.agent-fabric" ]]
assert $? "no hub was created by the refused install"
env HOME="$GUARD_HOME" FABRIC_HOME="$GUARD_HOME/.agent-fabric" bash "$REPO_DIR/install.sh" >/dev/null 2>&1
assert $? "explicit FABRIC_HOME overrides the guard"
rm -rf "$GUARD_HOME"

# ── Summary ──────────────────────────────────────────────────────────────────
echo
echo "──────────────────────────────"
printf 'passed: %d  failed: %d\n' "$PASS" "$FAIL"
if [[ "$FAIL" -eq 0 ]]; then
  printf '%sALL TESTS PASSED%s\n' "$GREEN" "$NC"
  exit 0
fi
printf '%sTESTS FAILED%s\n' "$RED" "$NC"
exit 1
