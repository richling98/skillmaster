# SkillMaster

SkillMaster is a local skills brain for AI agents.

It keeps one user-controlled master skills folder in sync with Claude Code and Codex skill folders, then generates a local `index.html` page where you can browse every skill, inspect the full `SKILL.md`, and copy a skill to paste anywhere.

The public repo contains tooling only. Your personal skills stay in your configured master folder.

## What You Get

- One canonical master skills folder that you choose.
- Import of existing Claude Code and Codex skills.
- Manual sync from master to Claude Code and Codex.
- Background bidirectional sync with deletion safeguards.
- A generated local skill library page at `$MASTER_DIR/index.html`.
- A `Copy` button for every skill so you can paste the full skill into email, chat, docs, or another AI surface.
- A bundled `add-new-skill` meta-skill for creating new SkillMaster skills.
- Tests that run against temporary fake skill folders without touching real user data.

## Supported Platforms

SkillMaster is designed for:

- macOS with `launchd` and `fswatch`
- Linux with `systemd --user` and `inotifywait`

The scripts are written in Bash and use standard Unix tools.

## Folder Model

SkillMaster coordinates three folders:

```text
Master folder          The private source of truth you choose during setup
Claude Code skills     ~/.claude/skills
Codex skills           ~/.agents/skills
```

Each skill is a directory containing a `SKILL.md` file:

```text
my-skill/
└── SKILL.md
```

The generated sharing page lives beside your skills:

```text
$MASTER_DIR/
├── index.html
├── my-skill/
│   └── SKILL.md
└── another-skill/
    └── SKILL.md
```

## Prerequisites

### Required

- `bash`
- `git`
- `cp`, `find`, `awk`, `sed`, `cksum`, `stat`

These are already available on a normal macOS or Linux development machine.

### Required for Background Sync

On macOS:

```bash
brew install fswatch
```

On Debian/Ubuntu Linux:

```bash
sudo apt update
sudo apt install inotify-tools
```

You can still run `bootstrap.sh`, `sync.sh`, and `generate-index.sh` without the background watcher dependency.

## Install From GitHub

### 1. Clone the repo

```bash
git clone https://github.com/richling98/skillmaster.git
cd skillmaster
```

### 2. Run setup

```bash
./setup.sh
```

Setup asks where your master skills folder should live.

Default:

```text
~/skills
```

Example custom location:

```text
~/Documents/Vibing/skills
```

Choose a folder that is private, durable, and easy for you to find. Do not choose this tooling repo itself as your master skills folder.

### 3. What setup does

`setup.sh` performs the full install:

1. Creates your master skills folder if it does not exist.
2. Creates Claude and Codex skills folders if needed.
3. Writes config to `~/.skillmaster/config`.
4. Imports existing skills from `~/.claude/skills` and `~/.agents/skills`.
5. Skips configured system/built-in skills.
6. Generates `$MASTER_DIR/index.html`.
7. Copies the bundled `add-new-skill` meta-skill into master, Claude Code, and Codex.
8. Installs the background watcher service unless you use `--no-service`.
9. Prints the important paths it created.

### 4. Open the local skill library

After setup, open:

```text
$MASTER_DIR/index.html
```

On macOS:

```bash
source ~/.skillmaster/config
open "$MASTER_DIR/index.html"
```

If your shell does not know `$MASTER_DIR`, read it from:

```bash
cat ~/.skillmaster/config
```

Then open the printed path manually in your browser.

## Non-Interactive Install

Use this for testing, scripting, or repeatable setup:

```bash
./setup.sh \
  --non-interactive \
  --master "$HOME/skills" \
  --claude "$HOME/.claude/skills" \
  --codex "$HOME/.agents/skills"
```

Skip background service installation:

```bash
./setup.sh --non-interactive --master "$HOME/skills" --no-service
```

## Configuration

SkillMaster writes:

```text
~/.skillmaster/config
```

Example:

```bash
MASTER_DIR="$HOME/skills"
CLAUDE_SKILLS_DIR="$HOME/.claude/skills"
CODEX_SKILLS_DIR="$HOME/.agents/skills"
LOG_FILE="$HOME/.skillmaster/sync.log"
EXCLUDED_SKILLS="skill-creator,gstack"
DEBOUNCE_SECONDS="0.5"
```

You can edit this file if your folders move.

After editing config, restart the watcher:

macOS:

```bash
launchctl unload "$HOME/Library/LaunchAgents/com.skillmaster.watcher.plist"
launchctl load "$HOME/Library/LaunchAgents/com.skillmaster.watcher.plist"
```

Linux:

```bash
systemctl --user restart skillmaster.service
```

## Commands

### Import existing skills

```bash
scripts/bootstrap.sh
```

Imports skills from Claude Code and Codex into the master folder.

Use non-interactive conflict handling:

```bash
scripts/bootstrap.sh --yes
```

When `--yes` sees a conflict, it keeps the existing master copy.

### Sync master to tools

```bash
scripts/sync.sh
```

Pushes all master skills to Claude Code and Codex.

Sync one skill:

```bash
scripts/sync.sh my-skill
```

Preview changes without writing files:

```bash
scripts/sync.sh --dry-run
```

Preview one skill:

```bash
scripts/sync.sh --dry-run my-skill
```

### Regenerate the local skill library page

```bash
scripts/generate-index.sh
```

Or explicitly pass the master folder:

```bash
scripts/generate-index.sh "$HOME/skills"
```

This rewrites:

```text
$MASTER_DIR/index.html
```

### Run the watcher in the foreground

```bash
scripts/watch.sh
```

Use this when debugging. Keep the terminal open.

### Install the watcher service

```bash
scripts/install-watcher.sh
```

Install but do not start:

```bash
scripts/install-watcher.sh --no-start
```

### Uninstall SkillMaster support files

```bash
scripts/uninstall.sh
```

Non-interactive:

```bash
scripts/uninstall.sh --yes
```

Uninstall removes SkillMaster services and support files, but preserves your master skills folder by default.

## Background Watcher Behavior

The watcher observes:

- `$MASTER_DIR`
- `~/.claude/skills`
- `~/.agents/skills`

When a skill is created or edited in any watched folder, SkillMaster syncs it to the other locations.

Loop prevention uses checksums. If source and destination content already match, no copy happens.

The watcher ignores generated artifacts such as:

```text
$MASTER_DIR/index.html
```

After the master folder changes, SkillMaster regenerates the local skill library page.

## Deletion Behavior

SkillMaster is intentionally conservative with deletes.

| Delete location | Behavior |
| --- | --- |
| Master folder | Can propagate outward to Claude Code and Codex after confirmation |
| Claude Code | Logged, but master is preserved |
| Codex | Logged, but master is preserved |

This prevents accidental data loss if a tool-side skill folder is deleted.

## Generated `index.html`

The generated local page includes:

- Search box
- One entry per skill
- Skill name
- Description from frontmatter when present
- Last updated time
- Expandable full `SKILL.md` preview
- `Copy` button for the raw markdown

The page is a static file. It does not require a local web server.

Copy behavior uses `navigator.clipboard.writeText()` with a fallback for stricter local-file browser permissions.

## Manual Acceptance Check

Run this after installation to confirm everything works on your machine.

### 1. Confirm setup paths

```bash
cat ~/.skillmaster/config
source ~/.skillmaster/config
```

Check that:

- `MASTER_DIR` is the folder you intended.
- `CLAUDE_SKILLS_DIR` points to your Claude Code skills folder.
- `CODEX_SKILLS_DIR` points to your Codex skills folder.
- `LOG_FILE` points somewhere under `~/.skillmaster`.

### 2. Confirm the generated page opens

Open:

```text
$MASTER_DIR/index.html
```

Check that:

- Expected skills are listed.
- Skill descriptions look reasonable.
- Expanding a skill shows the full `SKILL.md`.
- Search filters the list.

### 3. Confirm copy works

Click `Copy` on three skills.

Paste each into:

- a plain text editor
- a chat draft
- an email draft

Check that the pasted content is the full raw `SKILL.md`.

### 4. Create a skill in the master folder

```bash
mkdir -p "$MASTER_DIR/manual-master-test"
cat > "$MASTER_DIR/manual-master-test/SKILL.md" <<'EOF'
---
name: manual-master-test
description: Manual test skill created in the master folder.
---

# Manual Master Test

This skill verifies master-to-tool sync.
EOF
```

Wait a moment, then check:

```bash
test -f "$HOME/.claude/skills/manual-master-test/SKILL.md" && echo "Claude copy exists"
test -f "$HOME/.agents/skills/manual-master-test/SKILL.md" && echo "Codex copy exists"
```

Open `$MASTER_DIR/index.html` and confirm `manual-master-test` appears.

### 5. Create or edit a skill in Claude Code

```bash
mkdir -p "$HOME/.claude/skills/manual-claude-test"
cat > "$HOME/.claude/skills/manual-claude-test/SKILL.md" <<'EOF'
---
name: manual-claude-test
description: Manual test skill created in Claude Code.
---

# Manual Claude Test

This skill verifies Claude-to-master-to-Codex sync.
EOF
```

Wait a moment, then check:

```bash
test -f "$MASTER_DIR/manual-claude-test/SKILL.md" && echo "Master copy exists"
test -f "$HOME/.agents/skills/manual-claude-test/SKILL.md" && echo "Codex copy exists"
```

### 6. Create or edit a skill in Codex

```bash
mkdir -p "$HOME/.agents/skills/manual-codex-test"
cat > "$HOME/.agents/skills/manual-codex-test/SKILL.md" <<'EOF'
---
name: manual-codex-test
description: Manual test skill created in Codex.
---

# Manual Codex Test

This skill verifies Codex-to-master-to-Claude sync.
EOF
```

Wait a moment, then check:

```bash
test -f "$MASTER_DIR/manual-codex-test/SKILL.md" && echo "Master copy exists"
test -f "$HOME/.claude/skills/manual-codex-test/SKILL.md" && echo "Claude copy exists"
```

### 7. Confirm tool-side delete safety

Delete only the Claude copy:

```bash
rm -rf "$HOME/.claude/skills/manual-claude-test"
```

Wait a moment, then check:

```bash
test -f "$MASTER_DIR/manual-claude-test/SKILL.md" && echo "Master preserved"
```

The master copy should still exist.

### 8. Confirm dry-run sync

```bash
scripts/sync.sh --dry-run
```

The command should print what it would sync without changing files.

### 9. Inspect logs

```bash
tail -n 50 ~/.skillmaster/sync.log
```

Check that recent sync, index regeneration, and delete-safety events are understandable.

### 10. Restart the watcher

macOS:

```bash
launchctl unload "$HOME/Library/LaunchAgents/com.skillmaster.watcher.plist"
launchctl load "$HOME/Library/LaunchAgents/com.skillmaster.watcher.plist"
```

Linux:

```bash
systemctl --user restart skillmaster.service
systemctl --user status skillmaster.service
```

Make one more small edit to a test skill and confirm sync still works.

## Automated Verification

Run syntax checks:

```bash
bash -n setup.sh scripts/*.sh tests/run.sh
```

Run the integration tests:

```bash
tests/run.sh
```

The integration tests create temporary fake master, Claude, and Codex skill folders. They do not touch real user skill directories.

## Troubleshooting

### `fswatch` is missing on macOS

Install it:

```bash
brew install fswatch
```

Then reinstall or restart the watcher:

```bash
scripts/install-watcher.sh
```

### `inotifywait` is missing on Linux

Install it:

```bash
sudo apt update
sudo apt install inotify-tools
```

Then reinstall or restart the watcher:

```bash
scripts/install-watcher.sh
```

### The watcher is not syncing

Check config:

```bash
cat ~/.skillmaster/config
```

Check logs:

```bash
tail -n 100 ~/.skillmaster/sync.log
```

Run the watcher in the foreground:

```bash
scripts/watch.sh
```

Make a small skill edit and watch for errors.

### The generated page is stale

Regenerate it manually:

```bash
scripts/generate-index.sh
```

Then refresh the browser tab.

### Clipboard copy does not work

Some browsers restrict clipboard access for local files.

Try:

1. Click `View skill`.
2. Select the visible `SKILL.md` text manually.
3. Copy with the browser or operating system shortcut.

The page also includes a fallback copy path, but browser policies differ.

### A skill did not import

Check that the skill folder contains:

```text
SKILL.md
```

Check whether its folder name appears in:

```bash
grep EXCLUDED_SKILLS ~/.skillmaster/config
```

Excluded skills are skipped by bootstrap and sync.

### I chose the wrong master folder

Edit:

```bash
~/.skillmaster/config
```

Change `MASTER_DIR`, then create the folder if needed:

```bash
source ~/.skillmaster/config
mkdir -p "$MASTER_DIR"
```

Run bootstrap and regenerate the page:

```bash
scripts/bootstrap.sh
scripts/generate-index.sh "$MASTER_DIR"
```

Restart the watcher service.

## Uninstall

Run:

```bash
scripts/uninstall.sh
```

Or:

```bash
scripts/uninstall.sh --yes
```

By default, uninstall removes SkillMaster support files and services but preserves your master skills folder.

If you want to remove your master skills folder too, delete it manually after confirming you have a backup.

## Repository Contents

```text
README.md
setup.sh
scripts/
  bootstrap.sh
  common.sh
  generate-index.sh
  install-watcher.sh
  sync.sh
  uninstall.sh
  watch.sh
config/
  skillmaster.conf.example
launchd/
  com.skillmaster.watcher.plist
systemd/
  skillmaster.service
skills/
  add-new-skill/
    SKILL.md
tests/
  run.sh
plans/
  skillmaster-plan.html
```

## Privacy Model

SkillMaster does not upload skills anywhere.

The generated `index.html` is local. The copy button puts text on your clipboard only. You decide where to paste it.

If you want backup or multi-machine sync, put your master skills folder in a separate private repo or private synced folder. Do not commit private skills into this public tooling repo unless you intentionally want them public.
