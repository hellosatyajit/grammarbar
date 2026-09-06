#!/bin/zsh
set -euo pipefail
repo_dir="${0:A:h:h}"
temp_dir="$(mktemp -d)"
swiftc -parse-as-library \
    "$repo_dir/Sources/GrammarBar/EvalSuite.swift" \
    "$repo_dir/Tools/EvalScorerSmoke.swift" \
    -o "$temp_dir/EvalScorerSmoke"
"$temp_dir/EvalScorerSmoke"

swiftc -parse-as-library \
    "$repo_dir/Sources/GrammarBar/AppSettings.swift" \
    "$repo_dir/Sources/GrammarBar/GrammarClient.swift" \
    "$repo_dir/Sources/GrammarBar/EvalSuite.swift" \
    "$repo_dir/Sources/GrammarBar/EvalService.swift" \
    "$repo_dir/Sources/GrammarBar/EvalDashboardView.swift" \
    "$repo_dir/Tools/EvalDashboardSmoke.swift" \
    -o "$temp_dir/EvalDashboardSmoke"
"$temp_dir/EvalDashboardSmoke"
echo "Eval dashboard runtime smoke test passed"
