#!/bin/bash

# 自動ビルドスクリプト
# 使用法: ./auto-build.sh [オプション] [報告書ファイル]

set -e

# カラー出力の定義
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# エラーハンドリング
error_exit() {
    echo -e "${RED}エラー: $1${NC}" >&2
    exit 1
}

# 使用法の表示
show_usage() {
    cat << EOF
使用法: $0 [オプション] [報告書ファイル]

オプション:
  -h, --help           : このヘルプを表示
  -f, --format FORMAT  : 出力形式（html, pdf, both）デフォルト: html
  -c, --check          : ビルド前に引用チェックを実行
  -w, --watch          : ビルド後に監視モードを開始
  -s, --serve          : HTMLビルド後にローカルサーバーを起動
  -p, --port PORT      : サーバーポート（デフォルト: 8080）
  -o, --output NAME    : 出力ファイル名（拡張子なし）
  -q, --quiet          : 静音モード（最小限の出力）
  --check-urls         : URL有効性チェックも実行

報告書ファイル:
  ビルドする報告書のMarkdownファイル（デフォルト: reports/report.md）

例:
  # HTMLをビルドして監視
  $0 -w reports/my-report.md

  # PDFをビルドして引用チェック付き
  $0 -f pdf -c reports/my-report.md

  # HTMLビルド後にローカルサーバー起動
  $0 -s -p 3000 reports/my-report.md

  # HTML/PDF両方をビルド
  $0 -f both reports/my-report.md

EOF
}

# デフォルト値
REPORT_FILE="reports/report.md"
FORMAT="html"
CHECK_REFS=false
WATCH_MODE=false
SERVE_MODE=false
SERVER_PORT=8080
OUTPUT_NAME=""
QUIET_MODE=false
CHECK_URLS=false
PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

# オプション解析
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_usage
            exit 0
            ;;
        -f|--format)
            FORMAT="$2"
            shift 2
            ;;
        -c|--check)
            CHECK_REFS=true
            shift
            ;;
        -w|--watch)
            WATCH_MODE=true
            shift
            ;;
        -s|--serve)
            SERVE_MODE=true
            shift
            ;;
        -p|--port)
            SERVER_PORT="$2"
            shift 2
            ;;
        -o|--output)
            OUTPUT_NAME="$2"
            shift 2
            ;;
        -q|--quiet)
            QUIET_MODE=true
            shift
            ;;
        --check-urls)
            CHECK_URLS=true
            shift
            ;;
        *)
            REPORT_FILE="$1"
            shift
            ;;
    esac
done

# ログ出力関数
log() {
    if [ "$QUIET_MODE" = false ]; then
        echo -e "$1"
    fi
}

log_error() {
    echo -e "${RED}$1${NC}" >&2
}

# 報告書ファイルの存在確認
if [ ! -f "$REPORT_FILE" ]; then
    error_exit "報告書ファイル '$REPORT_FILE' が見つかりません"
fi

# 出力名の設定
if [ -z "$OUTPUT_NAME" ]; then
    OUTPUT_NAME=$(basename "$REPORT_FILE" .md)
fi

# プロセスIDファイル
PID_FILE="/tmp/auto_build_server_${OUTPUT_NAME}.pid"

# 既存サーバーの停止
stop_existing_server() {
    if [ -f "$PID_FILE" ]; then
        local old_pid=$(cat "$PID_FILE")
        if kill -0 "$old_pid" 2>/dev/null; then
            log "${YELLOW}既存のサーバー (PID: $old_pid) を停止します${NC}"
            kill "$old_pid" 2>/dev/null || true
            rm -f "$PID_FILE"
            sleep 1
        fi
    fi
}

# 引用チェック実行
run_reference_check() {
    log "${CYAN}=== 引用整合性チェック ===${NC}"

    local check_cmd="$PROJECT_ROOT/scripts/check-references.sh \"$REPORT_FILE\""

    if [ "$CHECK_URLS" = true ]; then
        check_cmd="$check_cmd --check-urls"
    fi

    if eval "$check_cmd"; then
        log "${GREEN}✓ 引用チェック完了${NC}"
        return 0
    else
        log_error "✗ 引用チェックで問題が見つかりました"
        read -p "続行しますか？ (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
}

# ビルド実行
run_build() {
    local format="$1"

    case $format in
        html|HTML)
            log "${CYAN}=== HTMLビルド ===${NC}"
            if "$PROJECT_ROOT/scripts/build-report.sh" html "$REPORT_FILE" "$OUTPUT_NAME"; then
                log "${GREEN}✓ HTMLビルド成功${NC}"
                return 0
            else
                log_error "✗ HTMLビルド失敗"
                return 1
            fi
            ;;
        pdf|PDF)
            log "${CYAN}=== PDFビルド ===${NC}"
            if "$PROJECT_ROOT/scripts/build-report.sh" pdf "$REPORT_FILE" "$OUTPUT_NAME"; then
                log "${GREEN}✓ PDFビルド成功${NC}"
                return 0
            else
                log_error "✗ PDFビルド失敗"
                return 1
            fi
            ;;
        both|BOTH)
            local html_result=0
            local pdf_result=0

            run_build html || html_result=$?
            run_build pdf || pdf_result=$?

            if [ $html_result -eq 0 ] && [ $pdf_result -eq 0 ]; then
                return 0
            else
                return 1
            fi
            ;;
        *)
            error_exit "不正な出力形式: $format (html, pdf, both のいずれかを指定)"
            ;;
    esac
}

# ローカルサーバー起動
start_server() {
    local html_file="$PROJECT_ROOT/output/html/${OUTPUT_NAME}.html"

    if [ ! -f "$html_file" ]; then
        log_error "HTMLファイルが見つかりません: $html_file"
        return 1
    fi

    stop_existing_server

    log "${CYAN}=== ローカルサーバー起動 ===${NC}"

    # Python3のHTTPサーバーを使用
    if command -v python3 &> /dev/null; then
        cd "$PROJECT_ROOT/output/html"
        python3 -m http.server "$SERVER_PORT" &
        local server_pid=$!
        echo $server_pid > "$PID_FILE"

        sleep 1
        if kill -0 "$server_pid" 2>/dev/null; then
            log "${GREEN}✓ サーバー起動成功${NC}"
            log "  URL: ${BLUE}http://localhost:${SERVER_PORT}/${OUTPUT_NAME}.html${NC}"

            # ブラウザで開く
            if command -v xdg-open &> /dev/null; then
                xdg-open "http://localhost:${SERVER_PORT}/${OUTPUT_NAME}.html" &
            elif command -v open &> /dev/null; then
                open "http://localhost:${SERVER_PORT}/${OUTPUT_NAME}.html" &
            fi
        else
            log_error "サーバーの起動に失敗しました"
            return 1
        fi
    elif command -v python &> /dev/null; then
        cd "$PROJECT_ROOT/output/html"
        python -m SimpleHTTPServer "$SERVER_PORT" &
        local server_pid=$!
        echo $server_pid > "$PID_FILE"

        sleep 1
        if kill -0 "$server_pid" 2>/dev/null; then
            log "${GREEN}✓ サーバー起動成功${NC}"
            log "  URL: ${BLUE}http://localhost:${SERVER_PORT}/${OUTPUT_NAME}.html${NC}"
        else
            log_error "サーバーの起動に失敗しました"
            return 1
        fi
    else
        log_error "PythonがインストールされていないためHTTPサーバーを起動できません"
        return 1
    fi
}

# 監視モード開始
start_watch() {
    log "${CYAN}=== 監視モード開始 ===${NC}"

    # ビルドコマンドの構築
    local build_cmd="$PROJECT_ROOT/scripts/auto-build.sh"

    if [ "$QUIET_MODE" = true ]; then
        build_cmd="$build_cmd -q"
    fi

    build_cmd="$build_cmd -f $FORMAT"

    if [ "$CHECK_REFS" = true ]; then
        build_cmd="$build_cmd -c"
    fi

    if [ -n "$OUTPUT_NAME" ]; then
        build_cmd="$build_cmd -o \"$OUTPUT_NAME\""
    fi

    build_cmd="$build_cmd \"$REPORT_FILE\""

    # 監視開始
    "$PROJECT_ROOT/scripts/watch-files.sh" \
        -e md,yaml,yml \
        -i 2 \
        "$(dirname "$REPORT_FILE")" \
        -- "$build_cmd"
}

# クリーンアップ処理
cleanup() {
    log ""
    log "${YELLOW}終了処理中...${NC}"
    stop_existing_server
    exit 0
}

# シグナルハンドラー設定
trap cleanup INT TERM

# メイン処理
log "${GREEN}=== 自動ビルドスクリプト ===${NC}"
log "報告書: $REPORT_FILE"
log "形式: $FORMAT"
log "出力名: $OUTPUT_NAME"

# 引用チェック
if [ "$CHECK_REFS" = true ]; then
    run_reference_check
fi

# ビルド実行
if run_build "$FORMAT"; then
    log "${GREEN}=== ビルド完了 ===${NC}"
else
    exit 1
fi

# サーバー起動
if [ "$SERVE_MODE" = true ] && [[ "$FORMAT" == "html" || "$FORMAT" == "both" ]]; then
    start_server
fi

# 監視モード
if [ "$WATCH_MODE" = true ]; then
    start_watch
elif [ "$SERVE_MODE" = true ]; then
    log ""
    log "${YELLOW}サーバー実行中 (Ctrl+Cで終了)${NC}"
    wait
fi

# 通常終了時のクリーンアップ
if [ "$SERVE_MODE" = false ] && [ "$WATCH_MODE" = false ]; then
    stop_existing_server
fi