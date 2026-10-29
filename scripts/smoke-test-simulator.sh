#!/usr/bin/env bash
# ビルド済みアプリを iOS Simulator にインストールして起動し、10秒後もプロセスが動いているか確認する。macOS 専用。
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
  echo "::error::ビルド済みの .app が見つかりません（$DD/Build/Products）"
  exit 1
fi
BUNDLE_ID="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$APP/Info.plist")"
echo "App: $APP ($BUNDLE_ID)"

xcrun simctl boot "$UDID" 2>/dev/null || true
xcrun simctl bootstatus "$UDID" -b > "$OUT/bootstatus.log" 2>&1
xcrun simctl install "$UDID" "$APP"
xcrun simctl launch "$UDID" "$BUNDLE_ID" | tee "$OUT/launch.txt"
sleep "$WAIT_SECONDS"

STATUS=0
if xcrun simctl spawn "$UDID" launchctl list | grep -q "$BUNDLE_ID"; then
  echo "起動から ${WAIT_SECONDS} 秒後もプロセスは動作中"
else
  echo "::error::起動から ${WAIT_SECONDS} 秒以内にアプリが終了しました（クラッシュの可能性）"
  STATUS=1
fi
xcrun simctl io "$UDID" screenshot "$OUT/launch.png" || true
find "$HOME/Library/Logs/DiagnosticReports" -name 'MyHome*' -newer "$OUT/launch.txt" -exec cp {} "$OUT/" \; 2>/dev/null || true
xcrun simctl shutdown "$UDID" 2>/dev/null || true

if [ -n "${GITHUB_STEP_SUMMARY:-}" ]; then
  if [ "$STATUS" = 0 ]; then RESULT="PASS（${WAIT_SECONDS}秒後も動作中）"; else RESULT="FAIL"; fi
  printf '## Simulator 起動テスト\n\n- 結果: %s\n- スクリーンショット: アーティファクト app-build-logs-xcode-* の smoke/launch.png\n' "$RESULT" >> "$GITHUB_STEP_SUMMARY"
fi
exit "$STATUS"
