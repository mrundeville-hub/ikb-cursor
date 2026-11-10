#!/bin/sh
# Build and install as a LaunchAgent (starts at login).
set -e
cd "$(dirname "$0")"
./build.sh
BIN="$(pwd)/ikb-cursor"
PLIST="$HOME/Library/LaunchAgents/local.ikb-cursor.plist"
cat > "$PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>Label</key><string>local.ikb-cursor</string>
<key>ProgramArguments</key><array><string>$BIN</string></array>
<key>RunAtLoad</key><true/>
<key>KeepAlive</key><dict><key>SuccessfulExit</key><false/></dict>
<key>ThrottleInterval</key><integer>10</integer>
<key>ProcessType</key><string>Interactive</string>
</dict></plist>
EOF
launchctl bootout "gui/$(id -u)/local.ikb-cursor" 2>/dev/null || true
launchctl bootstrap "gui/$(id -u)" "$PLIST"
echo "installed. Grant Accessibility to: $BIN"
