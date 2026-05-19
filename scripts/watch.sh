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
        while IFS= read -r tool_dir; do
          rm -rf -- "$tool_dir/$skill_name"
        done < <(tool_skill_dirs)
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

scan_state() {
  local output="$1"
  local temp_output="$output.$$"
  local source_dir
  local skill_dir
  local skill_name
  local skill_hash

  ensure_parent_dir "$output"
  {
    while IFS= read -r source_dir; do
      [[ -d "$source_dir" ]] || continue
      while IFS= read -r skill_dir; do
        skill_name="$(basename "$skill_dir")"
        [[ "$skill_name" == .* ]] && continue
        is_excluded_skill "$skill_name" && continue
        is_valid_skill_dir "$skill_dir" || continue
        skill_hash="$(hash_path "$skill_dir/SKILL.md")"
        printf '%s|%s|%s\n' "$source_dir" "$skill_name" "$skill_hash"
      done < <(find "$source_dir" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | sort)
    done < <(skill_source_dirs)
  } > "$temp_output"
  mv "$temp_output" "$output"
}

poll_loop() {
  local state_dir="$HOME/.skillmaster/state"
  local previous="$state_dir/watch-state.previous"
  local current="$state_dir/watch-state.current"
  local interval="${SKILLMASTER_POLL_SECONDS:-2}"
  local source_dir
  local skill_name
  local handled_change
  local _hash

  mkdir -p "$state_dir"
  scan_state "$previous"
  log_msg "Starting SkillMaster watcher in polling mode with $(wc -l < "$previous" | tr -d ' ') tracked skills"

  while true; do
    sleep "$interval"
    scan_state "$current"
    handled_change=0

    while IFS='|' read -r source_dir skill_name _hash; do
      [[ -n "$source_dir" && -n "$skill_name" ]] || continue
      if ! grep -Fq "$source_dir|$skill_name|" "$current"; then
        handle_event "$source_dir/$skill_name/SKILL.md"
        handled_change=1
        break
      fi
    done < "$previous"

    if [[ "$handled_change" == "1" ]]; then
      mv "$current" "$previous"
      continue
    fi

    while IFS='|' read -r source_dir skill_name _hash; do
      [[ -n "$source_dir" && -n "$skill_name" ]] || continue
      if ! grep -Fqx "$source_dir|$skill_name|$_hash" "$previous"; then
        handle_event "$source_dir/$skill_name/SKILL.md"
        handled_change=1
        break
      fi
    done < "$current"

    if [[ "$handled_change" == "1" ]]; then
      mv "$current" "$previous"
      continue
    fi

    mv "$current" "$previous"
  done
}

if [[ "${1:-}" == "--once" ]]; then
  shift
  handle_event "${1:-}"
  exit 0
fi

if [[ "${1:-}" == "--scan-state" ]]; then
  shift
  scan_state "${1:?missing output path}"
  exit 0
fi

ensure_skill_roots

if [[ "${SKILLMASTER_WATCH_MODE:-}" == "poll" ]]; then
  poll_loop
fi

log_msg "Starting SkillMaster watcher in fswatch mode"

if command -v fswatch >/dev/null 2>&1; then
  watch_dirs=()
  while IFS= read -r watch_dir; do
    [[ -d "$watch_dir" ]] && watch_dirs+=("$watch_dir")
  done < <(skill_source_dirs)
  fswatch -r "${watch_dirs[@]}" | while IFS= read -r changed_path; do
    handle_event "$changed_path"
  done
elif command -v inotifywait >/dev/null 2>&1; then
  watch_dirs=()
  while IFS= read -r watch_dir; do
    [[ -d "$watch_dir" ]] && watch_dirs+=("$watch_dir")
  done < <(skill_source_dirs)
  inotifywait -m -r -e create,modify,delete,move --format '%w%f' "${watch_dirs[@]}" | while IFS= read -r changed_path; do
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
