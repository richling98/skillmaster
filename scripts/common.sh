#!/usr/bin/env bash

skillmaster_root() {
  cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd
}

load_config() {
  local config_file="${SKILLMASTER_CONFIG:-$HOME/.skillmaster/config}"

  MASTER_DIR="${MASTER_DIR:-$HOME/skills}"
  CLAUDE_SKILLS_DIR="${CLAUDE_SKILLS_DIR:-$HOME/.claude/skills}"
  CODEX_SKILLS_DIR="${CODEX_SKILLS_DIR:-$HOME/.agents/skills}"
  LOG_FILE="${LOG_FILE:-$HOME/.skillmaster/sync.log}"
  EXCLUDED_SKILLS="${EXCLUDED_SKILLS:-skill-creator,gstack}"
  DEBOUNCE_SECONDS="${DEBOUNCE_SECONDS:-0.5}"

  if [[ -f "$config_file" ]]; then
    # shellcheck source=/dev/null
    source "$config_file"
  fi

  MASTER_DIR="${SKILLMASTER_MASTER_DIR:-$MASTER_DIR}"
  CLAUDE_SKILLS_DIR="${SKILLMASTER_CLAUDE_SKILLS_DIR:-$CLAUDE_SKILLS_DIR}"
  CODEX_SKILLS_DIR="${SKILLMASTER_CODEX_SKILLS_DIR:-$CODEX_SKILLS_DIR}"
  LOG_FILE="${SKILLMASTER_LOG:-$LOG_FILE}"
  EXCLUDED_SKILLS="${SKILLMASTER_EXCLUDES:-$EXCLUDED_SKILLS}"
  DEBOUNCE_SECONDS="${SKILLMASTER_DEBOUNCE_SECONDS:-$DEBOUNCE_SECONDS}"

  export MASTER_DIR CLAUDE_SKILLS_DIR CODEX_SKILLS_DIR LOG_FILE EXCLUDED_SKILLS DEBOUNCE_SECONDS
}

ensure_parent_dir() {
  mkdir -p "$(dirname "$1")"
}

log_msg() {
  ensure_parent_dir "$LOG_FILE"
  printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" >> "$LOG_FILE"
}

is_yes() {
  [[ "${SKILLMASTER_ASSUME_YES:-}" == "1" || "${SKILLMASTER_ASSUME_YES:-}" == "true" ]]
}

confirm() {
  local prompt="$1"
  if is_yes; then
    return 0
  fi
  printf '%s [y/N] ' "$prompt" >&2
  local answer
  read -r answer
  [[ "$answer" == "y" || "$answer" == "Y" || "$answer" == "yes" || "$answer" == "YES" ]]
}

is_excluded_skill() {
  local name="$1"
  local item
  local old_ifs="$IFS"
  IFS=','
  for item in $EXCLUDED_SKILLS; do
    item="${item#"${item%%[![:space:]]*}"}"
    item="${item%"${item##*[![:space:]]}"}"
    [[ "$name" == "$item" ]] && { IFS="$old_ifs"; return 0; }
  done
  IFS="$old_ifs"
  return 1
}

is_valid_skill_dir() {
  [[ -d "$1" && -f "$1/SKILL.md" ]]
}

hash_path() {
  local path="$1"
  if [[ ! -e "$path" ]]; then
    printf 'missing'
    return 0
  fi
  if [[ -f "$path" ]]; then
    cksum "$path" | awk '{print $1 ":" $2}'
    return 0
  fi
  (
    cd "$path" || exit 1
    find . -type f ! -name '.DS_Store' -print | sort | while IFS= read -r file; do
      printf '%s ' "$file"
      cksum "$file"
    done
  ) | cksum | awk '{print $1 ":" $2}'
}

skill_name_from_path() {
  local source_dir="$1"
  local changed_path="$2"
  local relative="${changed_path#"$source_dir"/}"
  printf '%s\n' "${relative%%/*}"
}

path_is_under() {
  local path="$1"
  local base="$2"
  [[ "$path" == "$base" || "$path" == "$base/"* ]]
}

detect_source_dir() {
  local changed_path="$1"
  if path_is_under "$changed_path" "$MASTER_DIR"; then
    printf '%s\n' "$MASTER_DIR"
  elif path_is_under "$changed_path" "$CLAUDE_SKILLS_DIR"; then
    printf '%s\n' "$CLAUDE_SKILLS_DIR"
  elif path_is_under "$changed_path" "$CODEX_SKILLS_DIR"; then
    printf '%s\n' "$CODEX_SKILLS_DIR"
  else
    return 1
  fi
}

copy_skill_dir() {
  local source_dir="$1"
  local dest_dir="$2"
  local skill_name="$3"
  mkdir -p "$dest_dir"
  rm -rf -- "$dest_dir/$skill_name"
  cp -R "$source_dir/$skill_name" "$dest_dir/$skill_name"
}

sync_skill_from() {
  local source_dir="$1"
  local skill_name="$2"
  local dry_run="${3:-0}"
  local source_skill="$source_dir/$skill_name"
  local dest
  local src_hash
  local dest_hash

  is_excluded_skill "$skill_name" && return 0
  is_valid_skill_dir "$source_skill" || return 0

  src_hash="$(hash_path "$source_skill")"
  for dest in "$MASTER_DIR" "$CLAUDE_SKILLS_DIR" "$CODEX_SKILLS_DIR"; do
    [[ "$dest" == "$source_dir" ]] && continue
    dest_hash="$(hash_path "$dest/$skill_name")"
    [[ "$src_hash" == "$dest_hash" ]] && continue

    if [[ "$dry_run" == "1" ]]; then
      printf 'Would sync %s -> %s\n' "$skill_name" "$dest"
    else
      copy_skill_dir "$source_dir" "$dest" "$skill_name"
      log_msg "Synced $skill_name from $source_dir to $dest"
    fi
  done
}

regenerate_index() {
  local root
  root="$(skillmaster_root)"
  "$root/scripts/generate-index.sh" "$MASTER_DIR"
}

write_config_file() {
  local config_file="$1"
  ensure_parent_dir "$config_file"
  cat > "$config_file" <<EOF
MASTER_DIR="$MASTER_DIR"
CLAUDE_SKILLS_DIR="$CLAUDE_SKILLS_DIR"
CODEX_SKILLS_DIR="$CODEX_SKILLS_DIR"
LOG_FILE="$LOG_FILE"
EXCLUDED_SKILLS="$EXCLUDED_SKILLS"
DEBOUNCE_SECONDS="$DEBOUNCE_SECONDS"
EOF
}
