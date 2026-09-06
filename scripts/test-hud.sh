#!/bin/zsh
set -euo pipefail
repo_dir="${0:A:h:h}"
temporary_binary="$(mktemp -d)/GrammarBarHUDSmoke"
swiftc -parse-as-library \
    "$repo_dir/Sources/GrammarBar/HUDController.swift" \
    "$repo_dir/Tools/HUDSmoke.swift" \
    -o "$temporary_binary"
"$temporary_binary"
echo "HUD runtime smoke test passed"
