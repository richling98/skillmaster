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
Usage: scripts/uninstall.sh [--yes]

Remove SkillMaster services and support files. The master skills folder is preserved.
EOF
      exit 0
      ;;
    *)
      printf 'Unknown argument: %s\n' "$1" >&2
      exit 2
      ;;
  esac
done

if [[ "$YES" != "1" ]] && ! confirm "Uninstall SkillMaster support files and preserve $MASTER_DIR?"; then
  printf 'Uninstall cancelled\n'
  exit 0
fi

case "$(uname -s)" in
  Darwin)
    plist="$HOME/Library/LaunchAgents/com.skillmaster.watcher.plist"
    if [[ -f "$plist" ]]; then
      launchctl unload "$plist" >/dev/null 2>&1 || true
      rm -f "$plist"
    fi
    ;;
  Linux)
    service="$HOME/.config/systemd/user/skillmaster.service"
    if [[ -f "$service" ]]; then
      systemctl --user disable --now skillmaster.service >/dev/null 2>&1 || true
      rm -f "$service"
      systemctl --user daemon-reload >/dev/null 2>&1 || true
    fi
    ;;
esac

rm -rf -- "$HOME/.skillmaster"

printf 'SkillMaster uninstalled. Preserved master skills folder: %s\n' "$MASTER_DIR"
