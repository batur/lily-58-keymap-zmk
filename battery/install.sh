#!/usr/bin/env bash
# Build the battery reader and install it as a LaunchAgent that refreshes
# ~/.cache/lily58-battery.json every 15 minutes. Hammerspoon reads that file.
#
#   battery/install.sh            build + install (re-run after editing the .swift file)
#   battery/install.sh --remove   uninstall
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
bin="$HOME/.local/bin/lily58-battery"
label="io.lily58.battery"
agent="$HOME/Library/LaunchAgents/$label.plist"
out="$HOME/.cache/lily58-battery.json"

launchctl bootout "gui/$(id -u)/$label" 2>/dev/null || true
if [ "${1:-}" = "--remove" ]; then
    rm -f "$agent" "$bin" "$out"
    echo "removed"
    exit 0
fi

mkdir -p "$(dirname "$bin")" "$(dirname "$agent")" "$(dirname "$out")"
swiftc -O "$here/lily58-battery.swift" -o "$bin" \
    -Xlinker -sectcreate -Xlinker __TEXT -Xlinker __info_plist -Xlinker "$here/Info.plist"

cat > "$agent" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>Label</key><string>$label</string>
<key>ProgramArguments</key><array>
<string>$bin</string><string>Lily58</string><string>$out</string>
</array>
<key>RunAtLoad</key><true/>
<key>StartInterval</key><integer>900</integer>
</dict></plist>
PLIST

launchctl bootstrap "gui/$(id -u)" "$agent"
echo "installed; levels will appear in $out"
