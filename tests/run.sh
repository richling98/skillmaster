#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

export HOME="$TMP_DIR/home"
export SKILLMASTER_CONFIG="$HOME/.skillmaster/config"
export SKILLMASTER_ASSUME_YES=1

MASTER="$TMP_DIR/master"
CLAUDE="$TMP_DIR/claude-skills"
CODEX="$TMP_DIR/codex-skills"
LOG="$TMP_DIR/sync.log"

mkdir -p "$HOME" "$MASTER" "$CLAUDE" "$CODEX"

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

assert_file() {
  [[ -f "$1" ]] || fail "expected file: $1"
}

assert_dir() {
  [[ -d "$1" ]] || fail "expected directory: $1"
}

assert_contains() {
  local file="$1"
  local text="$2"
  grep -Fq "$text" "$file" || fail "expected '$text' in $file"
}

assert_not_exists() {
  [[ ! -e "$1" ]] || fail "expected missing path: $1"
}

write_skill() {
  local base="$1"
  local name="$2"
  local body="$3"
  mkdir -p "$base/$name"
  printf '%s\n' "$body" > "$base/$name/SKILL.md"
}

write_config() {
  mkdir -p "$(dirname "$SKILLMASTER_CONFIG")"
  cat > "$SKILLMASTER_CONFIG" <<EOF
MASTER_DIR="$MASTER"
CLAUDE_SKILLS_DIR="$CLAUDE"
CODEX_SKILLS_DIR="$CODEX"
LOG_FILE="$LOG"
EXCLUDED_SKILLS="system-skill,gstack"
DEBOUNCE_SECONDS="0"
EOF
}

reset_env() {
  rm -rf "$MASTER" "$CLAUDE" "$CODEX" "$LOG" "$HOME/.skillmaster"
  mkdir -p "$HOME" "$MASTER" "$CLAUDE" "$CODEX"
}

test_generate_index() {
  reset_env
  write_config
  write_skill "$MASTER" "alpha-skill" $'---\nname: Alpha Skill\ndescription: Copies alpha safely\n---\n\nUse <alpha> & copy it.'
  write_skill "$MASTER" "beta-skill" $'No frontmatter here.\n\n```bash\necho beta\n```'

  "$ROOT_DIR/scripts/generate-index.sh" "$MASTER"

  assert_file "$MASTER/index.html"
  assert_contains "$MASTER/index.html" "Alpha Skill"
  assert_contains "$MASTER/index.html" "Copies alpha safely"
  assert_contains "$MASTER/index.html" "beta-skill"
  assert_contains "$MASTER/index.html" "copySkill("
  assert_contains "$MASTER/index.html" "Use &lt;alpha&gt; &amp; copy it."
}

test_sync_pushes_master_to_tools() {
  reset_env
  write_config
  write_skill "$MASTER" "sync-me" "description: Sync me"
  "$ROOT_DIR/scripts/generate-index.sh" "$MASTER"

  "$ROOT_DIR/scripts/sync.sh" --dry-run > "$TMP_DIR/dry-run.txt"
  assert_contains "$TMP_DIR/dry-run.txt" "Would sync sync-me"
  assert_not_exists "$CLAUDE/sync-me"

  "$ROOT_DIR/scripts/sync.sh"
  assert_file "$CLAUDE/sync-me/SKILL.md"
  assert_file "$CODEX/sync-me/SKILL.md"
  assert_not_exists "$CLAUDE/index.html"
  assert_contains "$LOG" "Synced sync-me"
}

test_bootstrap_imports_and_excludes() {
  reset_env
  write_config
  write_skill "$CLAUDE" "from-claude" "description: From Claude"
  write_skill "$CODEX" "from-codex" "description: From Codex"
  write_skill "$CODEX" "system-skill" "description: Built in"

  "$ROOT_DIR/scripts/bootstrap.sh" --yes

  assert_file "$MASTER/from-claude/SKILL.md"
  assert_file "$MASTER/from-codex/SKILL.md"
  assert_not_exists "$MASTER/system-skill"
}

test_watch_once_propagates_and_regenerates_index() {
  reset_env
  write_config
  write_skill "$CLAUDE" "watch-created" "description: Watch Created"

  "$ROOT_DIR/scripts/watch.sh" --once "$CLAUDE/watch-created/SKILL.md"

  assert_file "$MASTER/watch-created/SKILL.md"
  assert_file "$CODEX/watch-created/SKILL.md"
  assert_file "$MASTER/index.html"
  assert_contains "$MASTER/index.html" "Watch Created"
}

test_tool_delete_does_not_remove_master() {
  reset_env
  write_config
  write_skill "$MASTER" "keep-master" "description: Keep Master"
  write_skill "$CLAUDE" "keep-master" "description: Keep Master"
  rm -rf "$CLAUDE/keep-master"

  "$ROOT_DIR/scripts/watch.sh" --once "$CLAUDE/keep-master/SKILL.md" || true

  assert_file "$MASTER/keep-master/SKILL.md"
}

test_setup_and_uninstall_preserve_master() {
  reset_env
  write_skill "$CLAUDE" "setup-import" "description: Setup Import"

  "$ROOT_DIR/setup.sh" --non-interactive --master "$MASTER" --claude "$CLAUDE" --codex "$CODEX" --no-service

  assert_file "$SKILLMASTER_CONFIG"
  assert_file "$MASTER/setup-import/SKILL.md"
  assert_file "$MASTER/index.html"
  assert_file "$CLAUDE/add-new-skill/SKILL.md"
  assert_file "$CODEX/add-new-skill/SKILL.md"

  "$ROOT_DIR/scripts/uninstall.sh" --yes
  assert_file "$MASTER/setup-import/SKILL.md"
  assert_not_exists "$HOME/.skillmaster/config"
}

main() {
  test_generate_index
  test_sync_pushes_master_to_tools
  test_bootstrap_imports_and_excludes
  test_watch_once_propagates_and_regenerates_index
  test_tool_delete_does_not_remove_master
  test_setup_and_uninstall_preserve_master
  echo "All tests passed"
}

main "$@"
