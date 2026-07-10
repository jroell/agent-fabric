# Contributing to agent-fabric

Thanks for helping make AI agent setups less fragmented! Contributions of all sizes are
welcome — new harnesses, bug fixes, docs, and test cases.

## Ground rules

- **macOS first.** Scripts must run on stock macOS: bash 3.2 (no associative arrays, no
  `${var,,}`), BSD userland (`sed -i ''`, `stat -f`). CI runs on `macos-latest`.
- **Zero dependencies.** The CLI and installer use nothing beyond what ships with macOS
  (+ `git` for the curl-pipe path). Keep it that way.
- **Never touch the user's real files in tests.** Every test runs against a throwaway
  `$HOME` from `mktemp`. If your test needs a home directory, make one.
- **Additive by default.** The fabric must never replace a user's existing real skill or
  config without an explicit, backed-up, documented reason.

## Dev loop

```bash
git clone https://github.com/jroell/agent-fabric && cd agent-fabric
bash tests/run-tests.sh          # full sandboxed suite (~30s, never touches your HOME)
```

Every PR must keep the suite green and add assertions for new behavior.

## Adding a harness

One line in the registry in `bin/fabric`:

```
name|detect_dir|instruction_path|instruction_strategy|skills_dir|skills_strategy|cli|note
```

Then:

1. Pick strategies honestly: `symlink` only if the tool actually reads that file;
   `manual` if wiring can't be done by file (document why in the note).
2. Add the harness to the simulated-home setup and assertions in `tests/run-tests.sh`.
3. Add a row to the "What gets wired" table in `README.md`, with a footnote for any
   edge cases (see the Hermes footnote for the expected level of detail).
4. If the harness has quirks (files it owns, background processes that rewrite things),
   document them — quirks discovered later become incidents.

## Pull requests

- Small, focused PRs review fastest.
- Explain *why*, not just what — especially for strategy decisions (symlink vs manual).
- New behavior needs tests; changed behavior needs updated tests.

## Reporting issues

Include: macOS version, tool versions (`claude --version`, `codex --version`, ...),
`fabric status --json` output, and `fabric doctor` output. None of these contain secrets.
