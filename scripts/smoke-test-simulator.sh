#!/usr/bin/env bash
# ビルド済みアプリを iOS Simulator にインストールし、次の3通りで起動して、それぞれ数秒後もプロセスが動いているか確認する。macOS 専用。
#   default : 初期レイアウト
#   empty   : 項目 0 件（-MyHomeSampleItems 0）
#   many    : 1ページに 150 件（-MyHomeSampleItems 150 -MyHomeSampleItemsPerPage 150）
# スクリーンショットを build-logs/smoke/ に保存する。実機 iPad / Swift Playgrounds での動作確認の代わりにはならない。
set -euo pipefail

cd "$(dirname "$0")/.."
ROOT="$PWD"
DD="${DERIVED_DATA:-$ROOT/build/DerivedData}"
OUT="${OUT_DIR:-$ROOT/build-logs/smoke}"
UDID="${SIM_UDID:?SIM_UDID を指定してください（measure-app-build.sh が GitHub Actions では自動設定する）}"
WAIT_SECONDS="${WAIT_SECONDS:-10}"
mkdir -p "$OUT"

APP="$(find "$DD/Build/Products" -maxdepth 2 -name '*.app' -path '*iphonesimulator*' | head -n 1)"
if [ -z "$APP" ]; then
  echo "::error::ビルド済みの .app が見つかりません（${DD}/Build/Products）"
  exit 1
fi
BUNDLE_ID="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$APP/Info.plist")"
echo "App: $APP ($BUNDLE_ID)"

xcrun simctl boot "$UDID" 2>/dev/null || true
xcrun simctl bootstatus "$UDID" -b > "$OUT/bootstatus.log" 2>&1
xcrun simctl install "$UDID" "$APP"

STATUS=0
RESULT_LINES=""

# launch_case <名前> [起動引数...]
launch_case() {
  local name="$1"
  shift
  xcrun simctl terminate "$UDID" "$BUNDLE_ID" 2>/dev/null || true
  # ${1+"$@"}: 引数なしでも bash 3.2 の set -u で止まらないようにする。
  xcrun simctl launch "$UDID" "$BUNDLE_ID" ${1+"$@"} > "$OUT/launch-$name.txt"
  sleep "$WAIT_SECONDS"
  local result services
  # 一覧を変数に取ってから探す。`launchctl list | grep -q` だと、grep が見つけた時点で終わって
  # launchctl が SIGPIPE で異常終了し、pipefail のせいで「動いていない」と誤判定することがある。
  services="$(xcrun simctl spawn "$UDID" launchctl list 2>/dev/null || true)"
  if [[ "$services" == *"$BUNDLE_ID"* ]]; then
    result="PASS（${WAIT_SECONDS}秒後も動作中）"
  else
    result="FAIL（${WAIT_SECONDS}秒以内に終了。クラッシュの可能性）"
    echo "::error::${name}: ${result}"
    STATUS=1
  fi
  xcrun simctl io "$UDID" screenshot "$OUT/$name.png" > /dev/null 2>&1 || true
  echo "${name}: ${result}"
  RESULT_LINES="${RESULT_LINES}- ${name}: ${result}（smoke/${name}.png）
"
}

launch_case default
launch_case empty -MyHomeSampleItems 0
launch_case many -MyHomeSampleItems 150 -MyHomeSampleItemsPerPage 150

find "$HOME/Library/Logs/DiagnosticReports" -name 'MyHome*' -newer "$OUT/launch-default.txt" -exec cp {} "$OUT/" \; 2>/dev/null || true
xcrun simctl shutdown "$UDID" 2>/dev/null || true

if [ -n "${GITHUB_STEP_SUMMARY:-}" ]; then
  printf '## Simulator 起動テスト\n\n%s\nスクリーンショットはアーティファクト app-build-logs-xcode-* の smoke/ にある。\n' "$RESULT_LINES" >> "$GITHUB_STEP_SUMMARY"
fi
exit "$STATUS"
