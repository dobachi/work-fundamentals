#!/bin/bash

# 継続的ビルド統合スクリプト
# 使用法: ./continuous-build.sh [オプション] [報告書ファイル]

set -e

# カラー出力の定義
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
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

継続的ビルドシステムを起動し、ファイル変更を監視して自動的に以下を実行：
  1. 引用整合性チェック
  2. HTML/PDFビルド
  3. ライブリロード対応のローカルサーバー

オプション:
  -h, --help           : このヘルプを表示
  -f, --format FORMAT  : 出力形式（html, pdf, both）デフォルト: html
  -p, --port PORT      : サーバーポート（デフォルト: 8080）
  -i, --interval SEC   : 監視間隔（秒）デフォルト: 2
  --no-check          : 引用チェックをスキップ
  --no-server         : ローカルサーバーを起動しない
  --check-urls        : URL有効性チェックも実行
  --dashboard         : ダッシュボードモードで起動（統計情報表示）
  -q, --quiet         : 静音モード

報告書ファイル:
  ビルドする報告書のMarkdownファイル（デフォルト: reports/report.md）

プリセットモード:
  $0 --dev            : 開発モード（HTML、チェック付き、サーバー起動）
  $0 --prod           : 本番モード（両形式、URL含む完全チェック）
  $0 --quick          : クイックモード（HTMLのみ、チェックなし）

例:
  # 標準的な継続的ビルド
  $0 reports/my-report.md

  # 開発モードで起動
  $0 --dev

  # 本番ビルドモード
  $0 --prod reports/final-report.md

  # ダッシュボード付き
  $0 --dashboard reports/my-report.md

EOF
}

# デフォルト値
REPORT_FILE="reports/report.md"
FORMAT="html"
SERVER_PORT=8080
INTERVAL=2
CHECK_REFS=true
START_SERVER=true
CHECK_URLS=false
DASHBOARD_MODE=false
QUIET_MODE=false
PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
LOG_FILE="$PROJECT_ROOT/continuous-build.log"

# プリセット設定関数
apply_dev_preset() {
    FORMAT="html"
    CHECK_REFS=true
    START_SERVER=true
    CHECK_URLS=false
    DASHBOARD_MODE=false
    echo -e "${CYAN}開発モード設定を適用${NC}"
}

apply_prod_preset() {
    FORMAT="both"
    CHECK_REFS=true
    START_SERVER=false
    CHECK_URLS=true
    DASHBOARD_MODE=true
    echo -e "${CYAN}本番モード設定を適用${NC}"
}

apply_quick_preset() {
    FORMAT="html"
    CHECK_REFS=false
    START_SERVER=true
    CHECK_URLS=false
    DASHBOARD_MODE=false
    echo -e "${CYAN}クイックモード設定を適用${NC}"
}

# オプション解析
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_usage
            exit 0
            ;;
        --dev)
            apply_dev_preset
            shift
            ;;
        --prod)
            apply_prod_preset
            shift
            ;;
        --quick)
            apply_quick_preset
            shift
            ;;
        -f|--format)
            FORMAT="$2"
            shift 2
            ;;
        -p|--port)
            SERVER_PORT="$2"
            shift 2
            ;;
        -i|--interval)
            INTERVAL="$2"
            shift 2
            ;;
        --no-check)
            CHECK_REFS=false
            shift
            ;;
        --no-server)
            START_SERVER=false
            shift
            ;;
        --check-urls)
            CHECK_URLS=true
            shift
            ;;
        --dashboard)
            DASHBOARD_MODE=true
            shift
            ;;
        -q|--quiet)
            QUIET_MODE=true
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
    local message="$1"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    if [ "$QUIET_MODE" = false ]; then
        echo -e "$message"
    fi

    echo "[$timestamp] $message" >> "$LOG_FILE"
}

# 統計情報
BUILD_COUNT=0
SUCCESS_COUNT=0
FAIL_COUNT=0
START_TIME=$(date +%s)
LAST_BUILD_TIME=""

# ダッシュボード表示
show_dashboard() {
    if [ "$DASHBOARD_MODE" = true ] && [ "$QUIET_MODE" = false ]; then
        clear
        echo -e "${CYAN}╔══════════════════════════════════════════════════════╗${NC}"
        echo -e "${CYAN}║         継続的ビルドシステム - ダッシュボード        ║${NC}"
        echo -e "${CYAN}╚══════════════════════════════════════════════════════╝${NC}"
        echo ""
        echo -e "${YELLOW}監視対象:${NC} $REPORT_FILE"
        echo -e "${YELLOW}出力形式:${NC} $FORMAT"
        echo -e "${YELLOW}サーバー:${NC} http://localhost:$SERVER_PORT"
        echo ""
        echo -e "${GREEN}統計情報:${NC}"
        echo -e "  ビルド回数: $BUILD_COUNT"
        echo -e "  成功: ${GREEN}$SUCCESS_COUNT${NC} | 失敗: ${RED}$FAIL_COUNT${NC}"

        local current_time=$(date +%s)
        local uptime=$((current_time - START_TIME))
        local hours=$((uptime / 3600))
        local minutes=$(((uptime % 3600) / 60))
        local seconds=$((uptime % 60))

        echo -e "  稼働時間: ${hours}時間 ${minutes}分 ${seconds}秒"

        if [ -n "$LAST_BUILD_TIME" ]; then
            echo -e "  最終ビルド: $LAST_BUILD_TIME"
        fi

        echo ""
        echo -e "${MAGENTA}[監視中...]${NC} Ctrl+Cで終了"
        echo "----------------------------------------"
    fi
}

# プロセス管理
PID_FILE="/tmp/continuous_build_$$"
SERVER_PID=""
WATCH_PID=""

# クリーンアップ
cleanup() {
    log "${YELLOW}終了処理中...${NC}"

    # 監視プロセスの停止
    if [ -n "$WATCH_PID" ] && kill -0 "$WATCH_PID" 2>/dev/null; then
        kill "$WATCH_PID" 2>/dev/null || true
    fi

    # サーバーの停止
    if [ -n "$SERVER_PID" ] && kill -0 "$SERVER_PID" 2>/dev/null; then
        kill "$SERVER_PID" 2>/dev/null || true
    fi

    # 子プロセスの停止
    jobs -p | xargs -r kill 2>/dev/null || true

    rm -f "$PID_FILE"

    log "${GREEN}=== 継続的ビルドシステム終了 ===${NC}"

    # 最終統計表示
    if [ $BUILD_COUNT -gt 0 ] && [ "$QUIET_MODE" = false ]; then
        echo ""
        echo -e "${CYAN}=== セッション統計 ===${NC}"
        echo -e "総ビルド回数: $BUILD_COUNT"
        echo -e "成功: ${GREEN}$SUCCESS_COUNT${NC}"
        echo -e "失敗: ${RED}$FAIL_COUNT${NC}"

        local success_rate=0
        if [ $BUILD_COUNT -gt 0 ]; then
            success_rate=$((SUCCESS_COUNT * 100 / BUILD_COUNT))
        fi
        echo -e "成功率: ${success_rate}%"
    fi

    exit 0
}

# シグナルハンドラー
trap cleanup INT TERM EXIT

# ビルド実行関数
execute_build() {
    BUILD_COUNT=$((BUILD_COUNT + 1))
    LAST_BUILD_TIME=$(date '+%Y-%m-%d %H:%M:%S')

    show_dashboard

    log "${CYAN}[Build #$BUILD_COUNT] ビルド開始${NC}"

    # 引用チェック
    if [ "$CHECK_REFS" = true ]; then
        log "  引用チェック実行中..."

        local check_cmd="$PROJECT_ROOT/scripts/check-references.sh \"$REPORT_FILE\""
        if [ "$CHECK_URLS" = true ]; then
            check_cmd="$check_cmd --check-urls"
        fi

        if [ "$QUIET_MODE" = true ]; then
            eval "$check_cmd" > /dev/null 2>&1
            local check_result=$?
        else
            eval "$check_cmd"
            local check_result=$?
        fi

        if [ $check_result -ne 0 ]; then
            log "${YELLOW}  ⚠ 引用チェックで警告があります${NC}"
        else
            log "${GREEN}  ✓ 引用チェック完了${NC}"
        fi
    fi

    # ビルド実行
    local build_success=true

    case $FORMAT in
        html|HTML)
            if "$PROJECT_ROOT/scripts/build-report.sh" html "$REPORT_FILE" > /dev/null 2>&1; then
                log "${GREEN}  ✓ HTMLビルド成功${NC}"
            else
                log "${RED}  ✗ HTMLビルド失敗${NC}"
                build_success=false
            fi
            ;;
        pdf|PDF)
            if "$PROJECT_ROOT/scripts/build-report.sh" pdf "$REPORT_FILE" > /dev/null 2>&1; then
                log "${GREEN}  ✓ PDFビルド成功${NC}"
            else
                log "${RED}  ✗ PDFビルド失敗${NC}"
                build_success=false
            fi
            ;;
        both|BOTH)
            local html_ok=true
            local pdf_ok=true

            if "$PROJECT_ROOT/scripts/build-report.sh" html "$REPORT_FILE" > /dev/null 2>&1; then
                log "${GREEN}  ✓ HTMLビルド成功${NC}"
            else
                log "${RED}  ✗ HTMLビルド失敗${NC}"
                html_ok=false
            fi

            if "$PROJECT_ROOT/scripts/build-report.sh" pdf "$REPORT_FILE" > /dev/null 2>&1; then
                log "${GREEN}  ✓ PDFビルド成功${NC}"
            else
                log "${RED}  ✗ PDFビルド失敗${NC}"
                pdf_ok=false
            fi

            if [ "$html_ok" = false ] || [ "$pdf_ok" = false ]; then
                build_success=false
            fi
            ;;
    esac

    # 統計更新
    if [ "$build_success" = true ]; then
        SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
        log "${GREEN}[Build #$BUILD_COUNT] 完了${NC}"

        # ライブリロード通知（簡易版）
        if [ "$START_SERVER" = true ] && [ -n "$SERVER_PID" ]; then
            # タイムスタンプファイル更新でリロードを通知
            touch "$PROJECT_ROOT/output/html/.reload"
        fi
    else
        FAIL_COUNT=$((FAIL_COUNT + 1))
        log "${RED}[Build #$BUILD_COUNT] 失敗${NC}"
    fi

    echo ""
}

# サーバー起動
start_server() {
    if [ "$START_SERVER" = false ]; then
        return
    fi

    log "${CYAN}ローカルサーバー起動中...${NC}"

    # 簡易ライブリロード対応サーバースクリプト作成
    cat > /tmp/livereload_server_$$.py << 'EOSERVER'
#!/usr/bin/env python3
import http.server
import socketserver
import os
import sys
import time
from urllib.parse import urlparse

PORT = int(sys.argv[1]) if len(sys.argv) > 1 else 8080
DIRECTORY = sys.argv[2] if len(sys.argv) > 2 else "."

class ReloadHandler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=DIRECTORY, **kwargs)

    def end_headers(self):
        self.send_header('Cache-Control', 'no-cache, no-store, must-revalidate')
        self.send_header('Pragma', 'no-cache')
        self.send_header('Expires', '0')
        super().end_headers()

    def do_GET(self):
        if self.path == '/check-reload':
            reload_file = os.path.join(DIRECTORY, '.reload')
            if os.path.exists(reload_file):
                mtime = os.path.getmtime(reload_file)
                self.send_response(200)
                self.send_header('Content-Type', 'text/plain')
                self.end_headers()
                self.wfile.write(str(mtime).encode())
            else:
                self.send_response(404)
                self.end_headers()
        else:
            super().do_GET()

print(f"サーバー起動: http://localhost:{PORT}/")
with socketserver.TCPServer(("", PORT), ReloadHandler) as httpd:
    httpd.serve_forever()
EOSERVER

    # サーバー起動
    if command -v python3 &> /dev/null; then
        python3 /tmp/livereload_server_$$.py "$SERVER_PORT" "$PROJECT_ROOT/output/html" &
        SERVER_PID=$!
    elif command -v python &> /dev/null; then
        python /tmp/livereload_server_$$.py "$SERVER_PORT" "$PROJECT_ROOT/output/html" &
        SERVER_PID=$!
    else
        log "${YELLOW}Pythonがインストールされていません。サーバーなしで続行します。${NC}"
        START_SERVER=false
        return
    fi

    sleep 2

    if kill -0 "$SERVER_PID" 2>/dev/null; then
        log "${GREEN}✓ サーバー起動成功${NC}"
        log "  URL: ${BLUE}http://localhost:${SERVER_PORT}/${NC}"

        # ブラウザで開く
        if [ "$QUIET_MODE" = false ]; then
            if command -v xdg-open &> /dev/null; then
                xdg-open "http://localhost:${SERVER_PORT}/" 2>/dev/null &
            elif command -v open &> /dev/null; then
                open "http://localhost:${SERVER_PORT}/" 2>/dev/null &
            fi
        fi
    else
        log "${RED}サーバー起動失敗${NC}"
        START_SERVER=false
    fi
}

# メイン処理
log "${GREEN}=== 継続的ビルドシステム起動 ===${NC}"
log "設定:"
log "  報告書: $REPORT_FILE"
log "  形式: $FORMAT"
log "  監視間隔: ${INTERVAL}秒"
log "  引用チェック: $([ "$CHECK_REFS" = true ] && echo "有効" || echo "無効")"
log "  URLチェック: $([ "$CHECK_URLS" = true ] && echo "有効" || echo "無効")"
log "  サーバー: $([ "$START_SERVER" = true ] && echo "有効 (Port: $SERVER_PORT)" || echo "無効")"
log "  ダッシュボード: $([ "$DASHBOARD_MODE" = true ] && echo "有効" || echo "無効")"
log ""

# 報告書ファイルの存在確認
if [ ! -f "$REPORT_FILE" ]; then
    error_exit "報告書ファイル '$REPORT_FILE' が見つかりません"
fi

# 初回ビルド
execute_build

# サーバー起動
start_server

# 監視ループ開始
log "${GREEN}ファイル監視開始${NC}"
log "${YELLOW}Ctrl+Cで終了${NC}"
echo ""

# inotifyが使用可能か確認
if command -v inotifywait &> /dev/null; then
    # inotify版監視
    while true; do
        inotifywait -r -e modify,create,delete,move \
            --exclude '(\.git|output|\.swp|\.tmp|~)' \
            -q "$(dirname "$REPORT_FILE")" 2>/dev/null

        # 少し待機（連続した変更をまとめる）
        sleep 0.5

        execute_build
    done
else
    # ポーリング版監視
    log "${YELLOW}注: inotifywaitが利用できません。ポーリング監視を使用します。${NC}"

    LAST_CHECKSUM=""

    while true; do
        # チェックサム計算
        if command -v md5sum &> /dev/null; then
            CURRENT_CHECKSUM=$(find "$(dirname "$REPORT_FILE")" -name "*.md" -o -name "*.yaml" -o -name "*.yml" | \
                xargs md5sum 2>/dev/null | md5sum)
        elif command -v md5 &> /dev/null; then
            CURRENT_CHECKSUM=$(find "$(dirname "$REPORT_FILE")" -name "*.md" -o -name "*.yaml" -o -name "*.yml" | \
                xargs md5 -q 2>/dev/null | md5 -q)
        fi

        # 変更検出
        if [ "$CURRENT_CHECKSUM" != "$LAST_CHECKSUM" ] && [ -n "$LAST_CHECKSUM" ]; then
            execute_build
        fi

        LAST_CHECKSUM="$CURRENT_CHECKSUM"
        sleep "$INTERVAL"
    done
fi