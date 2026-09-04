#!/bin/bash
# Tăng build number trong pubspec.yaml: 6.0.3+1 -> 6.0.3+2
# Dùng: ./bump.sh           (tăng build number)
#       ./bump.sh 6.0.4     (đổi version, build number về 1)
set -euo pipefail
cd "$(dirname "$0")"

current=$(grep '^version:' pubspec.yaml | awk '{print $2}')
name="${current%+*}"
build="${current#*+}"

if [ $# -ge 1 ]; then
  name="$1"
  build=1
else
  build=$((build + 1))
fi

new="${name}+${build}"
# BSD sed (macOS)
sed -i '' "s/^version: .*/version: ${new}/" pubspec.yaml
echo "$current  ->  $new"
