#!/usr/bin/env bash
# MyHomeCore（UI に依存しない層）のビルド時間を計測し、単体テストを実行する。Linux / macOS 共通。
# 計測: クリーンビルド（1回）/ 変更なし再ビルド・Core 1ファイル変更後の増分ビルド（各 REPEAT 回の中央値）/ テストビルド / テスト実行
#
# 使い方:
#   scripts/measure-core-build.sh
#   SWIFT_EXTRA_FLAGS="-Xswiftc -swift-version -Xswiftc 6" scripts/measure-core-build.sh   # 本体を Swift 6 言語モードで
#
# SWIFT_EXTRA_FLAGS は本体（MyHomeCore）のビルドだけに使い、テストのビルドには TEST_EXTRA_FLAGS を使う。
# Swift 6.0.x の Linux 版 XCTest はテスト探索コードが Swift 6 言語モードでコンパイルできないため分けている。
set -euo pipefail

cd "$(dirname "$0")/.."
. scripts/lib-timing.sh

LOG_DIR="${LOG_DIR:-build-logs/core}"
SLOW_MS="${SLOW_MS:-50}"
REPEAT="${REPEAT:-3}"
# 多くのファイルが参照する型のファイルに、毎回違うコメントを書き足して計る（インターフェースは変わらない小変更）。
PROBE_FILE="${PROBE_FILE:-MyHome.swiftpm/Core/Models/HomeItem.swift}"
mkdir -p "$LOG_DIR"

touch_probe() {
  printf '\n// incremental build probe %s-%s\n' "$(date +%s)" "$1" >> "$PROBE_FILE"
}

SLOW_FLAGS=(-Xswiftc -Xfrontend -Xswiftc "-warn-long-function-bodies=$SLOW_MS"
  -Xswiftc -Xfrontend -Xswiftc "-warn-long-expression-type-checking=$SLOW_MS")
read -r -a EXTRA <<< "${SWIFT_EXTRA_FLAGS:-}"
read -r -a TEST_EXTRA <<< "${TEST_EXTRA_FLAGS:-}"
FLAGS=(${EXTRA[@]+"${EXTRA[@]}"} "${SLOW_FLAGS[@]}")
TEST_FLAGS=(${TEST_EXTRA[@]+"${TEST_EXTRA[@]}"} "${SLOW_FLAGS[@]}")

swift --version 2>&1 | tee "$LOG_DIR/toolchain.txt"
echo "本体の追加フラグ: ${SWIFT_EXTRA_FLAGS:-（なし）} / テストの追加フラグ: ${TEST_EXTRA_FLAGS:-（なし）}"

BACKUP="$(mktemp)"
cp "$PROBE_FILE" "$BACKUP"
restore_probe() { cp "$BACKUP" "$PROBE_FILE"; }
# 終了コードを保ったまま後片付けする（trap 内の最後のコマンドの結果で失敗が隠れないように）。
trap 'status=$?; restore_probe; rm -f "$BACKUP"; exit $status' EXIT

rm -rf .build
timed clean "クリーンビルド（MyHomeCore、1回）" swift build "${FLAGS[@]}"
timed_median noop "変更なし再ビルド" "$REPEAT" - swift build "${FLAGS[@]}"
timed_median incremental "増分ビルド（Core 1ファイル変更）" "$REPEAT" touch_probe swift build "${FLAGS[@]}"
restore_probe
timed test-build "テストのビルド" swift build --build-tests "${TEST_FLAGS[@]}"
timed test-run "テスト実行" swift test --skip-build

TEST_LINE="$(grep -E 'Executed [0-9]+ tests?' "$LOG_DIR/test-run.log" | tail -n 1 | sed -E 's/^[[:space:]]+//' || true)"
SLOW_REPORT="$(report_slow_type_checks "$LOG_DIR/clean.log" "$SLOW_MS")"
print_summary "MyHomeCore ビルド計測（$(head -n 1 "$LOG_DIR/toolchain.txt")）" "テスト: ${TEST_LINE:-不明}

$SLOW_REPORT"
