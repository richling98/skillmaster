# SkillMaster

SkillMaster is a local skills brain for AI agents. It keeps a user-controlled master skills folder in sync with Claude Code and Codex skill folders, and generates a local `index.html` page for viewing and copying every skill.

## Quick Start

```bash
./setup.sh
```

Setup asks where the master skills folder should live, imports existing skills from Claude Code and Codex, writes `~/.skillmaster/config`, generates `$MASTER_DIR/index.html`, and installs the watcher service.

## Main Commands

```bash
scripts/bootstrap.sh          # import existing Claude/Codex skills into master
scripts/sync.sh               # push master skills to Claude/Codex
scripts/sync.sh --dry-run     # preview sync changes
scripts/generate-index.sh     # regenerate the local skill library page
scripts/watch.sh              # run the watcher in the foreground
scripts/uninstall.sh          # remove services/support files, preserve master skills
```

## Verification

```bash
bash -n setup.sh scripts/*.sh tests/run.sh
tests/run.sh
```

The integration tests create temporary fake master, Claude, and Codex skill folders. They do not touch real user skill directories.

## Privacy Model

The public repo contains tooling only. Personal skills live in the configured master folder and are not committed here unless the user explicitly chooses to do that in a separate private repo.

## Generated Skill Library

SkillMaster writes `$MASTER_DIR/index.html`. Open it directly in a browser to browse all skills, expand the full `SKILL.md`, and copy a skill to the clipboard.
