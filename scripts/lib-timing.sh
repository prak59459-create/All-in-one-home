# 計測スクリプト共通の関数（source して使う）。bash 3.2（macOS 標準）でも動くように書く。
# 注意: 変数の直後に全角文字を続ける時は必ず ${var} と書く（bash 3.2 は全角文字を変数名の一部と解釈することがある）。

# 現在時刻（秒、小数3桁）。GNU date が無い環境（macOS）では perl を使う。
now() {
  local t
  t="$(date +%s.%N 2>/dev/null || true)"
  case "$t" in
    ''|*N*) perl -MTime::HiRes=time -e 'printf "%.3f\n", time' ;;
    *) echo "$t" ;;
  esac
}

RESULT_ROWS=""

# timed <ログ名> <表示名> <コマンド...>
# コマンドの出力は $LOG_DIR/<ログ名>.log に保存し、所要秒数を結果表に追加する。失敗したらログ末尾を出して終了する。
timed() {
  local key="$1" label="$2"
  shift 2
  local log="$LOG_DIR/$key.log"
  local start end secs
  start="$(now)"
  if ! "$@" >"$log" 2>&1; then
    echo "::error::${label} が失敗しました（ログ: ${log}）"
    tail -n 120 "$log"
    exit 1
  fi
  end="$(now)"
  secs="$(awk -v s="$start" -v e="$end" 'BEGIN { printf "%.2f", e - s }')"
  RESULT_ROWS="$RESULT_ROWS| $label | $secs |
"
  echo "$label: ${secs}s"
}

# 遅い型チェック警告（-warn-long-function-bodies / -warn-long-expression-type-checking）を時間の降順で表示する。
report_slow_type_checks() {
  local log="$1" limit="$2"
  local lines count
  lines="$(grep -E 'took [0-9]+ms to type-check' "$log" | sed -E 's/^.*\/(MyHome\.swiftpm|Tests)\//\1\//' | sort -u || true)"
  if [ -z "$lines" ]; then
    count=0
  else
    count="$(printf '%s\n' "$lines" | wc -l | tr -d ' ')"
  fi
  echo "### 型チェックが ${limit}ms を超えた関数・式: ${count} 件"
  if [ "$count" != "0" ]; then
    printf '%s\n' "$lines" | awk '{ match($0, /took [0-9]+ms/); ms = substr($0, RSTART + 5, RLENGTH - 7); print ms "\t" $0 }' \
      | sort -rn | head -n 20 | cut -f2- | sed 's/^/- /'
  fi
}

# 結果表を標準出力と（GitHub Actions 上なら）ジョブサマリーへ出力する。
print_summary() {
  local title="$1" extra="${2:-}"
  local body
  body="## $title

| 計測項目 | 秒 |
|---|---|
$RESULT_ROWS
$extra"
  printf '%s\n' "$body"
  if [ -n "${GITHUB_STEP_SUMMARY:-}" ]; then
    printf '%s\n' "$body" >> "$GITHUB_STEP_SUMMARY"
  fi
}
