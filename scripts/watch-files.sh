#!/bin/bash

# ファイル監視スクリプト
# 使用法: ./watch-files.sh [監視対象ディレクトリ] [コマンド]

set -e

# カラー出力の定義
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# エラーハンドリング
error_exit() {
    echo -e "${RED}エラー: $1${NC}" >&2
    exit 1
}

# 使用法の表示
show_usage() {
    cat << EOF
使用法: $0 [オプション] [監視対象] -- [実行コマンド]

オプション:
  -h, --help           : このヘルプを表示
  -i, --interval SEC   : 監視間隔（秒）デフォルト: 2
  -e, --extensions EXT : 監視する拡張子（カンマ区切り）デフォルト: md,yaml,yml
  -x, --exclude PATTERN: 除外パターン（正規表現）
  -v, --verbose        : 詳細出力モード
  -o, --once           : 初回起動時にコマンドを実行

監視対象:
  ディレクトリまたはファイル（デフォルト: reports/）

実行コマンド:
  ファイル変更時に実行するコマンド

例:
  # Markdown変更時にHTMLをビルド
  $0 reports/ -- scripts/build-report.sh html reports/report.md

  # 特定ファイルのみ監視
  $0 reports/report.md -- scripts/check-references.sh reports/report.md

  # 複数拡張子を監視
  $0 -e md,txt,yaml reports/ -- make build

EOF
}

# デフォルト値
WATCH_PATH="reports/"
INTERVAL=2
EXTENSIONS="md,yaml,yml"
EXCLUDE_PATTERN=""
VERBOSE=false
RUN_ONCE=false
COMMAND=""

# オプション解析
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_usage
            exit 0
            ;;
        -i|--interval)
            INTERVAL="$2"
            shift 2
            ;;
        -e|--extensions)
            EXTENSIONS="$2"
            shift 2
            ;;
        -x|--exclude)
            EXCLUDE_PATTERN="$2"
            shift 2
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        -o|--once)
            RUN_ONCE=true
            shift
            ;;
        --)
            shift
            COMMAND="$@"
            break
            ;;
        *)
            if [ -z "$COMMAND" ]; then
                WATCH_PATH="$1"
                shift
                if [ "$1" = "--" ]; then
                    shift
                    COMMAND="$@"
                    break
                fi
            else
                COMMAND="$COMMAND $1"
            fi
            shift
            ;;
    esac
done

# コマンドが指定されていない場合はエラー
if [ -z "$COMMAND" ]; then
    error_exit "実行コマンドが指定されていません。'--' の後にコマンドを指定してください。"
fi

# 監視対象の存在確認
if [ ! -e "$WATCH_PATH" ]; then
    error_exit "監視対象 '$WATCH_PATH' が存在しません"
fi

# inotifywaitコマンドの確認（Linux）
USE_INOTIFY=false
if command -v inotifywait &> /dev/null; then
    USE_INOTIFY=true
    echo -e "${GREEN}inotifywaitを使用した効率的な監視を行います${NC}"
fi

# 拡張子フィルタの準備
EXT_FILTER=""
if [ -n "$EXTENSIONS" ]; then
    # カンマ区切りをパイプ区切りに変換
    EXT_REGEX=$(echo "$EXTENSIONS" | sed 's/,/|/g')
    EXT_FILTER=".*\.\($EXT_REGEX\)$"
fi

# ログ出力関数
log_verbose() {
    if [ "$VERBOSE" = true ]; then
        echo -e "${BLUE}[DEBUG] $1${NC}"
    fi
}

# コマンド実行関数
execute_command() {
    local trigger_file="$1"
    echo -e "${YELLOW}[$(date '+%Y-%m-%d %H:%M:%S')] ファイル変更検出: $trigger_file${NC}"
    echo -e "${GREEN}コマンド実行: $COMMAND${NC}"

    # コマンドの実行時間を計測
    local start_time=$(date +%s)

    # コマンド実行
    if eval "$COMMAND"; then
        local end_time=$(date +%s)
        local elapsed=$((end_time - start_time))
        echo -e "${GREEN}✓ コマンド実行成功 (${elapsed}秒)${NC}"
    else
        echo -e "${RED}✗ コマンド実行失敗${NC}"
    fi

    echo "----------------------------------------"
}

# ファイル変更チェック関数（ポーリング版）
check_changes_polling() {
    local checksum_file="/tmp/watch_checksums_$$"

    # 初期チェックサム計算
    if [ -d "$WATCH_PATH" ]; then
        find "$WATCH_PATH" -type f | grep -E "$EXT_FILTER" 2>/dev/null | \
            while read file; do
                if [ -n "$EXCLUDE_PATTERN" ] && echo "$file" | grep -qE "$EXCLUDE_PATTERN"; then
                    continue
                fi
                if command -v md5sum &> /dev/null; then
                    md5sum "$file" 2>/dev/null
                elif command -v md5 &> /dev/null; then
                    md5 -q "$file" 2>/dev/null | xargs echo "$file"
                fi
            done > "$checksum_file"
    else
        if command -v md5sum &> /dev/null; then
            md5sum "$WATCH_PATH" 2>/dev/null > "$checksum_file"
        elif command -v md5 &> /dev/null; then
            md5 -q "$WATCH_PATH" 2>/dev/null | xargs echo "$WATCH_PATH" > "$checksum_file"
        fi
    fi

    local temp_file="/tmp/watch_checksums_temp_$$"

    while true; do
        sleep "$INTERVAL"

        # 現在のチェックサム計算
        if [ -d "$WATCH_PATH" ]; then
            find "$WATCH_PATH" -type f | grep -E "$EXT_FILTER" 2>/dev/null | \
                while read file; do
                    if [ -n "$EXCLUDE_PATTERN" ] && echo "$file" | grep -qE "$EXCLUDE_PATTERN"; then
                        continue
                    fi
                    if command -v md5sum &> /dev/null; then
                        md5sum "$file" 2>/dev/null
                    elif command -v md5 &> /dev/null; then
                        md5 -q "$file" 2>/dev/null | xargs echo "$file"
                    fi
                done > "$temp_file"
        else
            if command -v md5sum &> /dev/null; then
                md5sum "$WATCH_PATH" 2>/dev/null > "$temp_file"
            elif command -v md5 &> /dev/null; then
                md5 -q "$WATCH_PATH" 2>/dev/null | xargs echo "$WATCH_PATH" > "$temp_file"
            fi
        fi

        # 変更検出
        if ! diff -q "$checksum_file" "$temp_file" > /dev/null 2>&1; then
            # 変更されたファイルを特定
            local changed_file=""
            if command -v comm &> /dev/null; then
                changed_file=$(comm -13 <(sort "$checksum_file") <(sort "$temp_file") | head -1 | awk '{print $2}')
            fi

            if [ -z "$changed_file" ]; then
                changed_file="$WATCH_PATH"
            fi

            execute_command "$changed_file"
            cp "$temp_file" "$checksum_file"
        fi

        log_verbose "監視中... (Ctrl+Cで終了)"
    done

    # クリーンアップ
    rm -f "$checksum_file" "$temp_file"
}

# ファイル変更チェック関数（inotify版）
check_changes_inotify() {
    local events="modify,create,delete,move"

    echo -e "${GREEN}inotify監視開始: $WATCH_PATH${NC}"

    while true; do
        local changed_file=""

        if [ -d "$WATCH_PATH" ]; then
            changed_file=$(inotifywait -r -e $events --format '%w%f' -q "$WATCH_PATH" 2>/dev/null)
        else
            changed_file=$(inotifywait -e $events --format '%w%f' -q "$WATCH_PATH" 2>/dev/null)
        fi

        # 拡張子フィルタ
        if [ -n "$EXT_FILTER" ]; then
            if ! echo "$changed_file" | grep -qE "$EXT_FILTER"; then
                log_verbose "スキップ: $changed_file (拡張子フィルタ)"
                continue
            fi
        fi

        # 除外パターン
        if [ -n "$EXCLUDE_PATTERN" ]; then
            if echo "$changed_file" | grep -qE "$EXCLUDE_PATTERN"; then
                log_verbose "スキップ: $changed_file (除外パターン)"
                continue
            fi
        fi

        execute_command "$changed_file"
    done
}

# メイン処理
echo -e "${GREEN}=== ファイル監視スクリプト ===${NC}"
echo -e "監視対象: $WATCH_PATH"
echo -e "監視拡張子: $EXTENSIONS"
echo -e "監視間隔: ${INTERVAL}秒"
echo -e "実行コマンド: $COMMAND"
echo ""

# 初回実行
if [ "$RUN_ONCE" = true ]; then
    echo -e "${YELLOW}初回実行...${NC}"
    execute_command "$WATCH_PATH"
fi

# Ctrl+C時のクリーンアップ
trap "echo -e '\n${YELLOW}監視を終了します${NC}'; exit 0" INT TERM

echo -e "${GREEN}監視開始 (Ctrl+Cで終了)${NC}"
echo "----------------------------------------"

# 監視方法の選択
if [ "$USE_INOTIFY" = true ]; then
    check_changes_inotify
else
    echo -e "${YELLOW}注: inotifywaitがインストールされていません。ポーリング監視を使用します。${NC}"
    echo -e "${YELLOW}    効率的な監視のため、inotify-toolsのインストールを推奨します:${NC}"
    echo -e "${YELLOW}    Ubuntu/Debian: sudo apt-get install inotify-tools${NC}"
    echo ""
    check_changes_polling
fi