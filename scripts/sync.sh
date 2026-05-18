#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "$SCRIPT_DIR/common.sh"

load_config

DRY_RUN=0
SKILL_FILTER=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run)
      DRY_RUN=1
      shift
      ;;
    --help|-h)
      cat <<'EOF'
Usage: scripts/sync.sh [--dry-run] [skill-name]

Push skills from the SkillMaster master folder to Claude Code and Codex.
EOF
      exit 0
      ;;
    *)
      SKILL_FILTER="$1"
      shift
      ;;
  esac
done

mkdir -p "$MASTER_DIR" "$CLAUDE_SKILLS_DIR" "$CODEX_SKILLS_DIR"

if [[ -n "$SKILL_FILTER" ]]; then
  sync_skill_from "$MASTER_DIR" "$SKILL_FILTER" "$DRY_RUN"
else
  while IFS= read -r skill_dir; do
    sync_skill_from "$MASTER_DIR" "$(basename "$skill_dir")" "$DRY_RUN"
  done < <(find "$MASTER_DIR" -mindepth 1 -maxdepth 1 -type d | sort)
fi

if [[ "$DRY_RUN" != "1" ]]; then
  regenerate_index >/dev/null
fi
