#!/bin/zsh
set -euo pipefail
repo_dir="${0:A:h:h}"
temporary_binary="$(mktemp -d)/GrammarBarSettingsSmoke"
swiftc -parse-as-library \
    "$repo_dir/Sources/GrammarBar/AppSettings.swift" \
    "$repo_dir/Sources/GrammarBar/ShortcutRecorderView.swift" \
    "$repo_dir/Sources/GrammarBar/SettingsView.swift" \
    "$repo_dir/Tools/SettingsSmoke.swift" \
    -o "$temporary_binary"
"$temporary_binary"
echo "Settings runtime smoke test passed"
