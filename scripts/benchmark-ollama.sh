#!/bin/zsh
set -euo pipefail
repo_dir="${0:A:h:h}"
model="${1:-qwen3:0.6b}"
count="${2:-12}"
temporary_binary="$(mktemp -d)/GrammarBarOllamaBenchmark"
swiftc -parse-as-library \
    "$repo_dir/Sources/GrammarBar/AppSettings.swift" \
    "$repo_dir/Sources/GrammarBar/GrammarClient.swift" \
    "$repo_dir/Sources/GrammarBar/EvalSuite.swift" \
    "$repo_dir/Tools/OllamaBenchmark.swift" \
    -o "$temporary_binary"
"$temporary_binary" "$model" "$count"
