#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "$SCRIPT_DIR/common.sh"

load_config

handle_event() {
  local changed_path="$1"
  local source_dir
  local skill_name

  [[ -z "$changed_path" ]] && return 0
  [[ "$changed_path" == "$MASTER_DIR/index.html" ]] && return 0

  source_dir="$(detect_source_dir "$changed_path" 2>/dev/null || true)"
  [[ -n "$source_dir" ]] || return 0

  skill_name="$(skill_name_from_path "$source_dir" "$changed_path")"
  [[ -n "$skill_name" ]] || return 0
  [[ "$skill_name" == .* ]] && return 0
  is_excluded_skill "$skill_name" && return 0

  if [[ ! -d "$source_dir/$skill_name" ]]; then
    if [[ "$source_dir" == "$MASTER_DIR" ]]; then
      if confirm "Propagate deletion of $skill_name from master to Claude Code and Codex?"; then
        rm -rf -- "$CLAUDE_SKILLS_DIR/$skill_name" "$CODEX_SKILLS_DIR/$skill_name"
        log_msg "Deleted $skill_name from tool directories after master deletion"
        regenerate_index >/dev/null
      else
        log_msg "Master deletion observed for $skill_name but not propagated"
      fi
    else
      log_msg "Tool-side deletion observed for $skill_name in $source_dir; master preserved"
    fi
    return 0
  fi

  is_valid_skill_dir "$source_dir/$skill_name" || return 0
  sleep "$DEBOUNCE_SECONDS"
  sync_skill_from "$source_dir" "$skill_name" "0"

  if [[ "$source_dir" == "$MASTER_DIR" || -d "$MASTER_DIR/$skill_name" ]]; then
    regenerate_index >/dev/null
  fi
}

if [[ "${1:-}" == "--once" ]]; then
  shift
  handle_event "${1:-}"
  exit 0
fi

mkdir -p "$MASTER_DIR" "$CLAUDE_SKILLS_DIR" "$CODEX_SKILLS_DIR"
log_msg "Starting SkillMaster watcher"

if command -v fswatch >/dev/null 2>&1; then
  fswatch -r -L "$MASTER_DIR" "$CLAUDE_SKILLS_DIR" "$CODEX_SKILLS_DIR" | while IFS= read -r changed_path; do
    handle_event "$changed_path"
  done
elif command -v inotifywait >/dev/null 2>&1; then
  inotifywait -m -r -e create,modify,delete,move --format '%w%f' "$MASTER_DIR" "$CLAUDE_SKILLS_DIR" "$CODEX_SKILLS_DIR" | while IFS= read -r changed_path; do
    handle_event "$changed_path"
  done
else
  cat >&2 <<'EOF'
SkillMaster watcher requires fswatch on macOS or inotifywait on Linux.
Install with:
  macOS: brew install fswatch
  Linux: sudo apt install inotify-tools
EOF
  exit 1
fi
