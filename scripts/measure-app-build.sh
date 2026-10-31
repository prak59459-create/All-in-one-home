#!/usr/bin/env bash
# MyHome.swiftpm（SwiftUI アプリ本体）を xcodebuild で iOS Simulator 向けにビルドし、時間を計測する。macOS 専用。
# 計測: クリーンビルド（1回）/ 変更なし再ビルド・View 1ファイル変更・Core 型のインターフェース変更（各 REPEAT 回の中央値）
# 型チェックが SLOW_MS（既定 100ms）を超えた関数・式を一覧にする。
#
# iPad 版 Swift Playgrounds のビルド時間とは一致しない（端末・コンパイラ・ビルド方式が異なる）。傾向比較に使う。
set -euo pipefail

cd "$(dirname "$0")/.."
ROOT="$PWD"
. scripts/lib-timing.sh

LOG_DIR="${LOG_DIR:-build-logs/app}"
mkdir -p "$LOG_DIR"
LOG_DIR="$(cd "$LOG_DIR" && pwd)"
DD="${DERIVED_DATA:-$ROOT/build/DerivedData}"
SCHEME="${SCHEME:-MyHome}"
SLOW_MS="${SLOW_MS:-100}"
REPEAT="${REPEAT:-3}"
# 計測用に一時的に書き換えるファイル（計測後に元へ戻す）。
# View: 末端の小さな View（よくある小変更）。Core: 多くのファイルが参照する型（インターフェース変更の最悪寄りの例）。
VIEW_PROBE="${VIEW_PROBE:-MyHome.swiftpm/Features/Home/PageIndicatorView.swift}"
CORE_PROBE="${CORE_PROBE:-MyHome.swiftpm/Core/Models/HomeItem.swift}"
CORE_PROBE_TYPE="${CORE_PROBE_TYPE:-HomeItem}"

# 毎回内容が変わるように書き足す（同じ内容だと再コンパイルされない）。
touch_view_probe() {
  printf '\n// incremental build probe %s-%s\n' "$(date +%s)" "$1" >> "$ROOT/$VIEW_PROBE"
}
change_core_interface() {
  printf '\nextension %s { var buildProbe%s: Int { %s } }\n' "$CORE_PROBE_TYPE" "$1" "$1" >> "$ROOT/$CORE_PROBE"
}

# 利用可能な iOS Simulator から、最新ランタイムの iPad を選ぶ（なければ任意の iOS デバイス）。
pick_simulator() {
  xcrun simctl list devices available --json | python3 -c '
import json, re, sys
data = json.load(sys.stdin)["devices"]
def version(runtime):
    return [int(n) for n in re.findall(r"\d+", runtime.split("iOS-")[-1])]
devices = [(version(r), d["name"].startswith("iPad"), d["name"], d["udid"])
           for r, ds in data.items() if ".iOS-" in r for d in ds]
if not devices:
    sys.exit("iOS Simulator が見つかりません")
devices.sort(key=lambda d: (d[1], d[0]))
print(devices[-1][3] + "\t" + devices[-1][2])
'
}

if [ -z "${SIM_UDID:-}" ]; then
  PICKED="$(pick_simulator)"
  SIM_UDID="${PICKED%%$'\t'*}"
  SIM_NAME="${PICKED#*$'\t'}"
else
  SIM_NAME="（指定）"
fi
echo "Simulator: $SIM_NAME ($SIM_UDID)"
if [ -n "${GITHUB_ENV:-}" ]; then
  echo "SIM_UDID=$SIM_UDID" >> "$GITHUB_ENV"
fi

{ xcodebuild -version; swift --version; } 2>&1 | tee "$LOG_DIR/toolchain.txt"

XCB=(xcodebuild -scheme "$SCHEME" -destination "id=$SIM_UDID" -derivedDataPath "$DD"
  CODE_SIGNING_ALLOWED=NO
  "OTHER_SWIFT_FLAGS=\$(inherited) -Xfrontend -warn-long-function-bodies=$SLOW_MS -Xfrontend -warn-long-expression-type-checking=$SLOW_MS"
  build)

VIEW_BACKUP="$(mktemp)"
CORE_BACKUP="$(mktemp)"
cp "$ROOT/$VIEW_PROBE" "$VIEW_BACKUP"
cp "$ROOT/$CORE_PROBE" "$CORE_BACKUP"
restore_probes() {
  cp "$VIEW_BACKUP" "$ROOT/$VIEW_PROBE"
  cp "$CORE_BACKUP" "$ROOT/$CORE_PROBE"
}
# 終了コードを保ったまま後片付けする（trap 内の最後のコマンドの結果で失敗が隠れないように）。
trap 'status=$?; restore_probes; rm -f "$VIEW_BACKUP" "$CORE_BACKUP"; exit $status' EXIT

cd "$ROOT/MyHome.swiftpm"
rm -rf "$DD"
timed clean "クリーンビルド（パッケージ解決を含む、1回）" "${XCB[@]}"
timed_median noop "変更なし再ビルド" "$REPEAT" - "${XCB[@]}"
timed_median incremental-view "増分ビルド（View 1ファイル変更）" "$REPEAT" touch_view_probe "${XCB[@]}"
timed_median incremental-core "増分ビルド（Core 型のインターフェース変更）" "$REPEAT" change_core_interface "${XCB[@]}"
restore_probes
timed restore "元に戻して再ビルド（1回）" "${XCB[@]}"

SLOW_REPORT="$(report_slow_type_checks "$LOG_DIR/clean.log" "$SLOW_MS")"
print_summary "アプリ本体ビルド計測（$(head -n 1 "$LOG_DIR/toolchain.txt")、${SIM_NAME}）" "$SLOW_REPORT"
