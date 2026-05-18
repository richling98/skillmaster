#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/common.sh
source "$ROOT_DIR/scripts/common.sh"

NON_INTERACTIVE=0
NO_SERVICE=0

MASTER_DIR="${SKILLMASTER_MASTER_DIR:-$HOME/skills}"
CLAUDE_SKILLS_DIR="${SKILLMASTER_CLAUDE_SKILLS_DIR:-$HOME/.claude/skills}"
CODEX_SKILLS_DIR="${SKILLMASTER_CODEX_SKILLS_DIR:-$HOME/.agents/skills}"
LOG_FILE="${SKILLMASTER_LOG:-$HOME/.skillmaster/sync.log}"
EXCLUDED_SKILLS="${SKILLMASTER_EXCLUDES:-skill-creator,gstack}"
DEBOUNCE_SECONDS="${SKILLMASTER_DEBOUNCE_SECONDS:-0.5}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --non-interactive)
      NON_INTERACTIVE=1
      export SKILLMASTER_ASSUME_YES=1
      shift
      ;;
    --master)
      MASTER_DIR="$2"
      shift 2
      ;;
    --claude)
      CLAUDE_SKILLS_DIR="$2"
      shift 2
      ;;
    --codex)
      CODEX_SKILLS_DIR="$2"
      shift 2
      ;;
    --no-service)
      NO_SERVICE=1
      shift
      ;;
    --help|-h)
      cat <<'EOF'
Usage: ./setup.sh [--non-interactive] [--master PATH] [--claude PATH] [--codex PATH] [--no-service]

Set up SkillMaster, import existing skills, generate the local sharing page, and install the watcher.
EOF
      exit 0
      ;;
    *)
      printf 'Unknown argument: %s\n' "$1" >&2
      exit 2
      ;;
  esac
done

if [[ "$NON_INTERACTIVE" != "1" ]]; then
  printf 'Where should your master skills folder live?\n(default: %s) > ' "$MASTER_DIR"
  read -r answer
  [[ -n "$answer" ]] && MASTER_DIR="$answer"
fi

export MASTER_DIR CLAUDE_SKILLS_DIR CODEX_SKILLS_DIR LOG_FILE EXCLUDED_SKILLS DEBOUNCE_SECONDS

CONFIG_FILE="${SKILLMASTER_CONFIG:-$HOME/.skillmaster/config}"
write_config_file "$CONFIG_FILE"

mkdir -p "$MASTER_DIR" "$CLAUDE_SKILLS_DIR" "$CODEX_SKILLS_DIR"

"$ROOT_DIR/scripts/bootstrap.sh" --yes

mkdir -p "$MASTER_DIR/add-new-skill" "$CLAUDE_SKILLS_DIR/add-new-skill" "$CODEX_SKILLS_DIR/add-new-skill"
cp "$ROOT_DIR/skills/add-new-skill/SKILL.md" "$MASTER_DIR/add-new-skill/SKILL.md"
cp "$ROOT_DIR/skills/add-new-skill/SKILL.md" "$CLAUDE_SKILLS_DIR/add-new-skill/SKILL.md"
cp "$ROOT_DIR/skills/add-new-skill/SKILL.md" "$CODEX_SKILLS_DIR/add-new-skill/SKILL.md"

"$ROOT_DIR/scripts/generate-index.sh" "$MASTER_DIR" >/dev/null

if [[ "$NO_SERVICE" != "1" ]]; then
  "$ROOT_DIR/scripts/install-watcher.sh"
fi

cat <<EOF
SkillMaster setup complete.
Master folder: $MASTER_DIR
Claude skills: $CLAUDE_SKILLS_DIR
Codex skills: $CODEX_SKILLS_DIR
Skill library: $MASTER_DIR/index.html
Config: $CONFIG_FILE
EOF
