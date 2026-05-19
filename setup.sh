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
CODEX_SKILLS_DIRS="${SKILLMASTER_CODEX_SKILLS_DIRS:-}"
LOG_FILE="${SKILLMASTER_LOG:-$HOME/.skillmaster/sync.log}"
EXCLUDED_SKILLS="${SKILLMASTER_EXCLUDES:-skill-creator,gstack}"
DEBOUNCE_SECONDS="${SKILLMASTER_DEBOUNCE_SECONDS:-0.5}"
EXTRA_SKILLS_DIRS="${SKILLMASTER_EXTRA_SKILLS_DIRS:-}"

trim_input() {
  local value="$1"
  value="${value#"${value%%[![:space:]]*}"}"
  value="${value%"${value##*[![:space:]]}"}"
  printf '%s' "$value"
}

expand_user_path() {
  local value="$1"
  case "$value" in
    "~")
      printf '%s' "$HOME"
      ;;
    "~/"*)
      printf '%s/%s' "$HOME" "${value#~/}"
      ;;
    *)
      printf '%s' "$value"
      ;;
  esac
}

validate_master_dir() {
  local candidate="$1"
  local expanded
  expanded="$(expand_user_path "$candidate")"

  case "$expanded" in
    /*)
      ;;
    *)
      printf 'Invalid path: %s\n' "$candidate"
      printf 'Please enter an absolute path, such as %s, or press Enter for the default.\n' "$HOME/skills"
      return 1
      ;;
  esac

  case "$expanded" in
    "$ROOT_DIR"|"$ROOT_DIR"/*)
      printf 'Invalid path: %s\n' "$expanded"
      printf 'Please choose a master skills folder outside the SkillMaster tooling repo.\n'
      return 1
      ;;
  esac

  if ! mkdir -p "$expanded" 2>/dev/null; then
    printf 'Invalid path: %s\n' "$expanded"
    printf 'SkillMaster could not create that folder. Check the filepath and permissions, then try again.\n'
    return 1
  fi

  if [[ ! -d "$expanded" || ! -w "$expanded" ]]; then
    printf 'Invalid path: %s\n' "$expanded"
    printf 'SkillMaster needs a writable folder. Choose a folder you can write to, then try again.\n'
    return 1
  fi

  MASTER_DIR="$expanded"
  return 0
}

prompt_for_master_dir() {
  local default_dir="$MASTER_DIR"
  local answer
  while true; do
    cat <<EOF
Where should your master skills folder live?
Default: $default_dir
- Press Enter to use the default.
- Or paste the full absolute filepath to the folder you want to use.
EOF
    printf '> '
    if ! read -r answer; then
      answer=""
    fi
    answer="$(trim_input "$answer")"
    if [[ -z "$answer" ]]; then
      answer="$default_dir"
    fi
    validate_master_dir "$answer" && break
  done
}

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
  prompt_for_master_dir
else
  validate_master_dir "$MASTER_DIR"
fi

if [[ -z "$CODEX_SKILLS_DIRS" ]]; then
  CODEX_SKILLS_DIRS="$CODEX_SKILLS_DIR:${CODEX_HOME:-$HOME/.codex}/skills"
fi

export MASTER_DIR CLAUDE_SKILLS_DIR CODEX_SKILLS_DIR CODEX_SKILLS_DIRS LOG_FILE EXCLUDED_SKILLS DEBOUNCE_SECONDS EXTRA_SKILLS_DIRS

CONFIG_FILE="${SKILLMASTER_CONFIG:-$HOME/.skillmaster/config}"
write_config_file "$CONFIG_FILE"

ensure_skill_roots

"$ROOT_DIR/scripts/bootstrap.sh" --yes

mkdir -p "$MASTER_DIR/add-new-skill" "$CLAUDE_SKILLS_DIR/add-new-skill"
cp "$ROOT_DIR/skills/add-new-skill/SKILL.md" "$MASTER_DIR/add-new-skill/SKILL.md"
cp "$ROOT_DIR/skills/add-new-skill/SKILL.md" "$CLAUDE_SKILLS_DIR/add-new-skill/SKILL.md"
while IFS= read -r codex_dir; do
  mkdir -p "$codex_dir/add-new-skill"
  cp "$ROOT_DIR/skills/add-new-skill/SKILL.md" "$codex_dir/add-new-skill/SKILL.md"
done < <(codex_skill_dirs)

"$ROOT_DIR/scripts/generate-index.sh" "$MASTER_DIR" >/dev/null

if [[ "$NO_SERVICE" != "1" ]]; then
  "$ROOT_DIR/scripts/install-watcher.sh"
fi

cat <<EOF
SkillMaster setup complete.
Master folder: $MASTER_DIR
Claude skills: $CLAUDE_SKILLS_DIR
Codex skills:
EOF
while IFS= read -r codex_dir; do
  printf '  %s\n' "$codex_dir"
done < <(codex_skill_dirs)
cat <<EOF
Skill library: $MASTER_DIR/index.html
Config: $CONFIG_FILE
EOF
