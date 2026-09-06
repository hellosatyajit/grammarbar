#!/bin/zsh
set -euo pipefail
repo_dir="${0:A:h:h}"
"$repo_dir/scripts/build-app.sh" release >/dev/null
app="$repo_dir/dist/GrammarBar.app"
plutil -lint "$app/Contents/Info.plist"
test "$(plutil -extract LSUIElement raw "$app/Contents/Info.plist")" = "true"
test "$(plutil -extract CFBundlePackageType raw "$app/Contents/Info.plist")" = "APPL"
codesign --verify --deep --strict "$app"
test -x "$app/Contents/MacOS/GrammarBar"
"$repo_dir/scripts/test-hud.sh"
"$repo_dir/scripts/test-settings.sh"
"$repo_dir/scripts/test-evals.sh"
echo "GrammarBar verification passed: $app"
