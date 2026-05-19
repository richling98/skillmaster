#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
# shellcheck source=common.sh
source "$SCRIPT_DIR/common.sh"

load_config

NO_START=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --no-start)
      NO_START=1
      shift
      ;;
    --help|-h)
      cat <<'EOF'
Usage: scripts/install-watcher.sh [--no-start]

Install the SkillMaster watcher as a user-level background service.
EOF
      exit 0
      ;;
    *)
      printf 'Unknown argument: %s\n' "$1" >&2
      exit 2
      ;;
  esac
done

RUNTIME_DIR="$HOME/.skillmaster/runtime"
RUNTIME_SCRIPTS_DIR="$RUNTIME_DIR/scripts"
mkdir -p "$RUNTIME_SCRIPTS_DIR"
cp "$ROOT_DIR/scripts/"*.sh "$RUNTIME_SCRIPTS_DIR/"
chmod +x "$RUNTIME_SCRIPTS_DIR/"*.sh
WATCH_PROGRAM="$RUNTIME_SCRIPTS_DIR/watch.sh"

case "$(uname -s)" in
  Darwin)
    plist="$HOME/Library/LaunchAgents/com.skillmaster.watcher.plist"
    mkdir -p "$(dirname "$plist")"
    cat > "$plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>com.skillmaster.watcher</string>
  <key>ProgramArguments</key>
  <array>
    <string>$WATCH_PROGRAM</string>
  </array>
  <key>EnvironmentVariables</key>
  <dict>
    <key>SKILLMASTER_CONFIG</key>
    <string>${SKILLMASTER_CONFIG:-$HOME/.skillmaster/config}</string>
    <key>PATH</key>
    <string>/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin</string>
    <key>SKILLMASTER_WATCH_MODE</key>
    <string>poll</string>
    <key>SKILLMASTER_ASSUME_YES</key>
    <string>1</string>
  </dict>
  <key>RunAtLoad</key>
  <true/>
  <key>KeepAlive</key>
  <true/>
  <key>StandardOutPath</key>
  <string>$HOME/.skillmaster/watcher.out.log</string>
  <key>StandardErrorPath</key>
  <string>$HOME/.skillmaster/watcher.err.log</string>
</dict>
</plist>
EOF
    if [[ "$NO_START" != "1" ]]; then
      launchctl unload "$plist" >/dev/null 2>&1 || true
      launchctl load "$plist"
    fi
    printf 'Installed launchd watcher at %s\n' "$plist"
    printf 'Runtime scripts copied to %s\n' "$RUNTIME_SCRIPTS_DIR"
    ;;
  Linux)
    service_dir="$HOME/.config/systemd/user"
    service="$service_dir/skillmaster.service"
    mkdir -p "$service_dir"
    cat > "$service" <<EOF
[Unit]
Description=SkillMaster watcher

[Service]
Type=simple
Environment=SKILLMASTER_CONFIG=${SKILLMASTER_CONFIG:-$HOME/.skillmaster/config}
Environment=PATH=/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin
Environment=SKILLMASTER_WATCH_MODE=poll
Environment=SKILLMASTER_ASSUME_YES=1
ExecStart=$WATCH_PROGRAM
Restart=always
RestartSec=2

[Install]
WantedBy=default.target
EOF
    if [[ "$NO_START" != "1" ]]; then
      systemctl --user daemon-reload
      systemctl --user enable --now skillmaster.service
    fi
    printf 'Installed systemd watcher at %s\n' "$service"
    printf 'Runtime scripts copied to %s\n' "$RUNTIME_SCRIPTS_DIR"
    ;;
  *)
    printf 'Unsupported OS: %s\n' "$(uname -s)" >&2
    exit 1
    ;;
esac
