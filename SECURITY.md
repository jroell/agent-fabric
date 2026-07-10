# Security Policy

## Design posture

agent-fabric manages **instructions and skills**, never credentials:

- The hub contains no secrets by design; configs it writes never embed tokens.
- Anything the fabric replaces is backed up first to `~/.agent-fabric/.backups/<date>/`.
- The installer refuses to overwrite an existing hub without explicit consent
  (`--adopt` / `FABRIC_HOME`).
- Scripts are plain bash you can read in one sitting — no compiled blobs, no network
  calls after install (the curl-pipe installer clones this repo once).

## Reporting a vulnerability

Please open a [GitHub Security Advisory](https://github.com/jroell/agent-fabric/security/advisories/new)
(private) rather than a public issue for anything sensitive — e.g. symlink-escape issues,
backup-path traversal, or ways a malicious skill/hub layout could write outside expected
locations. Expect an initial response within a week.
