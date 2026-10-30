#!/usr/bin/env bash
# ビルド済みアプリを iOS Simulator にインストールし、次の通りに起動して、それぞれ数秒後もプロセスが動いているか確認する。macOS 専用。
#   default : 初期レイアウト（保存ファイルなし）
#   empty   : 項目 0 件（-MyHomeSampleItems 0。検証用の起動なので保存しない）
#   many    : 1ページに 150 件（-MyHomeSampleItems 150 -MyHomeSampleItemsPerPage 150）
#   restore : 保存ファイル（scripts/fixtures/home-restore.json、形式の版 1）を置いて起動し、その配置で復元されるか（T2-7、版 1 → 2 の移行）
#   editing : フォルダとウィジェット入りの保存ファイル（home-folder.json、版 3）で、編集モードで起動（-MyHomeStartEditing）
#   folder  : 同じファイルで、フォルダを開いて起動（-MyHomeOpenFolder folder.check）
#   app-*   : ミニアプリの保存ファイル（scripts/fixtures/apps/*.json）を置き、そのミニアプリを開いて起動（-MyHomeOpenFeature <名前>）。
#             メモ・タスク・電卓・単位変換・テキストツールの5つ。保存ファイルが読めた（別名に退避されていない）かも確かめる
#   app-aiAssistant : AI の画面を開いて起動。端末内モデルが使えるか（使えない時はその理由）の表示を確かめる（モデルは読み込まない）
#   app-weather : 天気の保存ファイル（通信はオフ、前回取得した天気。make-weather-fixture.py が今の時刻に合わせて作る）を置いて
#             天気を開く。通信しないまま前回の天気が表示されるか、保存ファイルが読めたかを確かめる
#   broken  : 壊れた保存ファイルを置いて起動し、初期配置で起動して元のファイルを別名で残すか（T2-2）
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

# record_check <名前> <PASS/FAIL> <説明>
record_check() {
  if [ "$2" != "PASS" ]; then
    echo "::error::${1}: ${3}"
    STATUS=1
  fi
  echo "${1}: ${2}（${3}）"
  RESULT_LINES="${RESULT_LINES}- ${1}: ${2}（${3}）
"
}

launch_case default
launch_case empty -MyHomeSampleItems 0
launch_case many -MyHomeSampleItems 150 -MyHomeSampleItemsPerPage 150

# 保存先はアプリのデータ領域の Library/Application Support/MyHome/home.json（FileHomeArchiveStorage）
DATA_DIR="$(xcrun simctl get_app_container "$UDID" "$BUNDLE_ID" data)/Library/Application Support/MyHome"
xcrun simctl terminate "$UDID" "$BUNDLE_ID" 2>/dev/null || true
mkdir -p "$DATA_DIR"
cp "$ROOT/scripts/fixtures/home-restore.json" "$DATA_DIR/home.json"
launch_case restore
if [ -f "$DATA_DIR/home.json" ] && [ -z "$(find "$DATA_DIR" -name 'home.unreadable-*.json')" ]; then
  record_check restore-file PASS "保存ファイルを読み込めた（別名に退避されていない。表示は restore.png）"
else
  record_check restore-file FAIL "保存ファイルが読み込めず、別名に退避された"
fi

xcrun simctl terminate "$UDID" "$BUNDLE_ID" 2>/dev/null || true
cp "$ROOT/scripts/fixtures/home-folder.json" "$DATA_DIR/home.json"
launch_case editing -MyHomeStartEditing
launch_case folder -MyHomeOpenFolder folder.check
if [ -z "$(find "$DATA_DIR" -name 'home.unreadable-*.json')" ]; then
  record_check folder-file PASS "フォルダ入りの保存ファイルを読み込めた（表示は editing.png / folder.png）"
else
  record_check folder-file FAIL "フォルダ入りの保存ファイルが読み込めず、別名に退避された"
fi

# ミニアプリの保存先は Library/Application Support/MyHome/Apps/<名前>.json（MiniAppLibrary）
xcrun simctl terminate "$UDID" "$BUNDLE_ID" 2>/dev/null || true
mkdir -p "$DATA_DIR/Apps"
cp "$ROOT"/scripts/fixtures/apps/*.json "$DATA_DIR/Apps/"
for feature in notes tasks calculator unitConverter textTools; do
  launch_case "app-$feature" -MyHomeOpenFeature "$feature"
done
if [ -z "$(find "$DATA_DIR/Apps" -name '*.unreadable-*.json')" ]; then
  record_check miniapp-files PASS "ミニアプリの保存ファイルを読み込めた（表示は app-*.png）"
else
  record_check miniapp-files FAIL "ミニアプリの保存ファイルが読み込めず、別名に退避された"
fi
launch_case app-aiAssistant -MyHomeOpenFeature aiAssistant

# 天気は通信をオフにしたまま開く（CI から Open-Meteo に接続しない）
xcrun simctl terminate "$UDID" "$BUNDLE_ID" 2>/dev/null || true
python3 "$ROOT/scripts/fixtures/make-weather-fixture.py" "$DATA_DIR/Apps/weather.json"
launch_case app-weather -MyHomeOpenFeature weather
if [ -z "$(find "$DATA_DIR/Apps" -name 'weather.unreadable-*.json')" ]; then
  record_check weather-file PASS "天気の保存ファイルを読み込めた（通信はオフのまま。表示は app-weather.png）"
else
  record_check weather-file FAIL "天気の保存ファイルが読み込めず、別名に退避された"
fi

xcrun simctl terminate "$UDID" "$BUNDLE_ID" 2>/dev/null || true
printf '{ broken' > "$DATA_DIR/home.json"
launch_case broken
if [ -n "$(find "$DATA_DIR" -name 'home.unreadable-*.json')" ]; then
  record_check broken-file PASS "壊れたファイルを消さずに別名で残した（説明の表示は broken.png）"
else
  record_check broken-file FAIL "壊れたファイルが別名で残っていない"
fi
cp -R "$DATA_DIR" "$OUT/saved-data" 2>/dev/null || true

find "$HOME/Library/Logs/DiagnosticReports" -name 'MyHome*' -newer "$OUT/launch-default.txt" -exec cp {} "$OUT/" \; 2>/dev/null || true
xcrun simctl shutdown "$UDID" 2>/dev/null || true

if [ -n "${GITHUB_STEP_SUMMARY:-}" ]; then
  printf '## Simulator 起動テスト\n\n%s\nスクリーンショットはアーティファクト app-build-logs-xcode-* の smoke/ にある。\n' "$RESULT_LINES" >> "$GITHUB_STEP_SUMMARY"
fi
exit "$STATUS"
