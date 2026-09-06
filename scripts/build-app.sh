#!/bin/zsh
set -euo pipefail
repo_dir="${0:A:h:h}"
configuration="${1:-release}"
swift build --package-path "$repo_dir" -c "$configuration"
binary_path="$(swift build --package-path "$repo_dir" -c "$configuration" --show-bin-path)/GrammarBar"
app_dir="$repo_dir/dist/GrammarBar.app"
mkdir -p "$app_dir/Contents/MacOS"
cp "$repo_dir/Info.plist" "$app_dir/Contents/Info.plist"
cp "$binary_path" "$app_dir/Contents/MacOS/GrammarBar"
codesign --force --deep --sign - "$app_dir"
echo "$app_dir"
