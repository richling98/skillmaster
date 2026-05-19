#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "$SCRIPT_DIR/common.sh"

load_config

YES=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --yes|-y)
      YES=1
      export SKILLMASTER_ASSUME_YES=1
      shift
      ;;
    --help|-h)
      cat <<'EOF'
Usage: scripts/bootstrap.sh [--yes]

Import existing Claude Code and Codex skills into the SkillMaster master folder.
EOF
      exit 0
      ;;
    *)
      printf 'Unknown argument: %s\n' "$1" >&2
      exit 2
      ;;
  esac
done

ensure_skill_roots

imported=0
skipped=0
conflicts=0

import_skill() {
  local source_dir="$1"
  local skill_name="$2"
  local source_skill="$source_dir/$skill_name"
  local master_skill="$MASTER_DIR/$skill_name"

  [[ "$skill_name" == .* ]] && { skipped=$((skipped + 1)); return 0; }
  is_excluded_skill "$skill_name" && { skipped=$((skipped + 1)); return 0; }
  is_valid_skill_dir "$source_skill" || return 0

  if [[ ! -d "$master_skill" ]]; then
    copy_skill_dir "$source_dir" "$MASTER_DIR" "$skill_name"
    imported=$((imported + 1))
    log_msg "Imported $skill_name from $source_dir"
    return 0
  fi

  if [[ "$(hash_path "$source_skill")" == "$(hash_path "$master_skill")" ]]; then
    skipped=$((skipped + 1))
    return 0
  fi

  conflicts=$((conflicts + 1))
  printf 'Conflict for skill "%s"\n' "$skill_name" >&2

  if [[ "$YES" == "1" || -n "${SKILLMASTER_ASSUME_YES:-}" ]]; then
    printf 'Keeping existing master copy for %s\n' "$skill_name" >&2
    log_msg "Conflict for $skill_name; kept master copy"
  elif confirm "Replace master copy of $skill_name with version from $source_dir?"; then
    copy_skill_dir "$source_dir" "$MASTER_DIR" "$skill_name"
    imported=$((imported + 1))
    log_msg "Replaced master copy of $skill_name from $source_dir"
  else
    log_msg "Conflict for $skill_name; kept master copy"
  fi
}

while IFS= read -r source_dir; do
  [[ "$source_dir" == "$MASTER_DIR" ]] && continue
  [[ -d "$source_dir" ]] || continue
  while IFS= read -r skill_dir; do
    import_skill "$source_dir" "$(basename "$skill_dir")"
  done < <(find "$source_dir" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | sort)
done < <(skill_source_dirs)

regenerate_index >/dev/null

printf 'Imported %s skills, skipped %s, conflicts %s\n' "$imported" "$skipped" "$conflicts"
