#!/usr/bin/env bash
# SwiftUI を使うファイル（App / DesignSystem / Features）を構文解析だけ行う。Linux 向けの簡易チェック。
# 型チェックは行わないため、SwiftUI API の誤用は検出できない（macOS の xcodebuild で確認する）。
set -euo pipefail

cd "$(dirname "$0")/.."
FILES=()
while IFS= read -r f; do
  FILES+=("$f")
done < <(find MyHome.swiftpm -name '*.swift' -not -path 'MyHome.swiftpm/Core/*' -not -name 'Package.swift' | sort)

if [ "${#FILES[@]}" -eq 0 ]; then
  echo "構文チェック対象のファイルがありません"
  exit 0
fi
swiftc -parse "${FILES[@]}"
echo "構文チェック OK: ${#FILES[@]} ファイル"
