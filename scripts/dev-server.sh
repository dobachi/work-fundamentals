#!/bin/bash

# Quarto開発サーバー - プレビュー + 自動ビルドの統合環境
# 使用法: ./dev-server.sh [options]

set -e

# カラー出力の定義
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'

# プロジェクトルートディレクトリ
PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
QUARTO_CONFIG="$PROJECT_ROOT/_quarto.yml"

# デフォルト設定
PREVIEW_PORT=3000
BUILD_FORMAT="html"
WATCH_DIR="$PROJECT_ROOT/reports"
ENABLE_AUTO_BUILD=true
BROWSER_OPEN=true

# PIDファイル（プロセス管理用）
PREVIEW_PID_FILE="$PROJECT_ROOT/.quarto-preview.pid"
BUILD_PID_FILE="$PROJECT_ROOT/.quarto-auto-build.pid"
DEV_SERVER_PID_FILE="$PROJECT_ROOT/.dev-server.pid"

# 終了時のクリーンアップ
cleanup() {
    echo -e "\n${YELLOW}開発サーバーを停止中...${NC}"

    # 子プロセスの停止
    if [ -f "$PREVIEW_PID_FILE" ]; then
        PREVIEW_PID=$(cat "$PREVIEW_PID_FILE" 2>/dev/null)
        if [ -n "$PREVIEW_PID" ] && kill -0 "$PREVIEW_PID" 2>/dev/null; then
            echo "  プレビューサーバーを停止中... (PID: $PREVIEW_PID)"
            kill -TERM "$PREVIEW_PID" 2>/dev/null || true
            wait "$PREVIEW_PID" 2>/dev/null || true
        fi
        rm -f "$PREVIEW_PID_FILE"
    fi

    if [ -f "$BUILD_PID_FILE" ]; then
        BUILD_PID=$(cat "$BUILD_PID_FILE" 2>/dev/null)
        if [ -n "$BUILD_PID" ] && kill -0 "$BUILD_PID" 2>/dev/null; then
            echo "  自動ビルドプロセスを停止中... (PID: $BUILD_PID)"
            kill -TERM "$BUILD_PID" 2>/dev/null || true
            wait "$BUILD_PID" 2>/dev/null || true
        fi
        rm -f "$BUILD_PID_FILE"
    fi

    # 関連するQuartoプロセスも停止
    pkill -f "quarto preview" 2>/dev/null || true
    pkill -f "auto-build-quarto.sh" 2>/dev/null || true

    rm -f "$DEV_SERVER_PID_FILE"
    echo -e "${GREEN}✓ 開発サーバーが正常に停止しました${NC}"
    exit 0
}

trap cleanup SIGINT SIGTERM EXIT

# 使用法の表示
show_usage() {
    cat << EOF
使用法: $0 [options]

オプション:
  --port PORT          : プレビューサーバーのポート番号 [デフォルト: 3000]
  --format FORMAT      : 自動ビルド形式 (html, pdf, all) [デフォルト: html]
  --watch-dir DIR      : 監視ディレクトリ [デフォルト: reports/]
  --no-auto-build      : 自動ビルドを無効化（プレビューのみ）
  --no-browser         : ブラウザ自動オープンを無効化
  --help               : このヘルプを表示

機能:
  ✨ プレビューサーバー: リアルタイム更新
  🔨 自動ビルド: ファイル保存時に自動ビルド
  🔄 統合環境: 開発に最適化された環境

推奨ワークフロー:
  1. このスクリプトを起動
  2. ブラウザでプレビューを確認
  3. .qmdファイルを編集・保存
  4. → 自動ビルド + プレビュー更新

例:
  $0                              # デフォルト設定で開始
  $0 --port 4000                  # ポート4000で開始
  $0 --format pdf                 # PDF自動ビルド有効
  $0 --no-auto-build             # プレビューのみ
  $0 --watch-dir docs/           # docsディレクトリを監視

停止方法:
  Ctrl+C で統合停止

EOF
}

# 引数の解析
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --port)
                PREVIEW_PORT="$2"
                shift 2
                ;;
            --format)
                BUILD_FORMAT="$2"
                shift 2
                ;;
            --watch-dir)
                WATCH_DIR="$2"
                shift 2
                ;;
            --no-auto-build)
                ENABLE_AUTO_BUILD=false
                shift
                ;;
            --no-browser)
                BROWSER_OPEN=false
                shift
                ;;
            --help)
                show_usage
                exit 0
                ;;
            *)
                echo -e "${RED}エラー: 不明なオプション '$1'${NC}"
                show_usage
                exit 1
                ;;
        esac
    done
}

# 依存関係の確認
check_dependencies() {
    local missing_tools=()

    # Quartoの確認
    if ! command -v quarto &> /dev/null; then
        missing_tools+=("quarto")
    fi

    # 自動ビルド用ツールの確認（有効な場合のみ）
    if [ "$ENABLE_AUTO_BUILD" = "true" ]; then
        if command -v inotifywait &> /dev/null; then
            WATCH_TOOL="inotifywait"
        elif command -v fswatch &> /dev/null; then
            WATCH_TOOL="fswatch"
        else
            missing_tools+=("inotify-tools (Linux) または fswatch (macOS)")
        fi
    fi

    if [ ${#missing_tools[@]} -gt 0 ]; then
        echo -e "${RED}エラー: 以下のツールがインストールされていません:${NC}"
        for tool in "${missing_tools[@]}"; do
            echo "  - $tool"
        done
        echo ""
        echo "インストール方法:"
        echo "  Quarto: scripts/setup-quarto.sh"
        echo "  Ubuntu/Debian: sudo apt-get install inotify-tools"
        echo "  macOS: brew install fswatch"
        exit 1
    fi
}

# 重複実行のチェック
check_duplicate() {
    if [ -f "$DEV_SERVER_PID_FILE" ]; then
        OLD_PID=$(cat "$DEV_SERVER_PID_FILE")
        if kill -0 "$OLD_PID" 2>/dev/null; then
            echo -e "${RED}エラー: 開発サーバーは既に実行中です (PID: $OLD_PID)${NC}"
            echo "停止するには: kill $OLD_PID"
            exit 1
        else
            rm -f "$DEV_SERVER_PID_FILE"
        fi
    fi

    # 現在のPIDを記録
    echo $$ > "$DEV_SERVER_PID_FILE"
}

# プロジェクト設定の確認
check_project_setup() {
    if [ ! -f "$QUARTO_CONFIG" ]; then
        echo -e "${YELLOW}警告: _quarto.yml が見つかりません${NC}"
        read -p "Quartoプロジェクトをセットアップしますか？ (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            "$PROJECT_ROOT/scripts/setup-quarto.sh"
        else
            echo "セットアップをスキップします"
        fi
    fi

    if [ ! -d "$WATCH_DIR" ]; then
        echo -e "${YELLOW}警告: 監視ディレクトリ '$WATCH_DIR' が見つかりません${NC}"
        mkdir -p "$WATCH_DIR"
        echo "ディレクトリを作成しました: $WATCH_DIR"
    fi
}

# プレビューサーバーの起動
start_preview_server() {
    echo -e "${CYAN}=== プレビューサーバー起動 ===${NC}"

    cd "$PROJECT_ROOT"

    local preview_cmd="quarto preview --port $PREVIEW_PORT"

    if [ "$BROWSER_OPEN" = "false" ]; then
        preview_cmd="$preview_cmd --no-browser"
    fi

    echo -e "${GREEN}プレビューサーバーを起動中...${NC}"
    echo "URL: http://localhost:$PREVIEW_PORT"

    # バックグラウンドでプレビューサーバーを起動
    $preview_cmd &
    PREVIEW_PID=$!
    echo $PREVIEW_PID > "$PREVIEW_PID_FILE"

    echo -e "${GREEN}✓ プレビューサーバーが起動しました (PID: $PREVIEW_PID)${NC}"

    # サーバーの起動を待機
    sleep 3

    # サーバーが正常に起動したかチェック
    if ! kill -0 "$PREVIEW_PID" 2>/dev/null; then
        echo -e "${RED}エラー: プレビューサーバーの起動に失敗しました${NC}"
        return 1
    fi
}

# 自動ビルドの起動
start_auto_build() {
    if [ "$ENABLE_AUTO_BUILD" = "false" ]; then
        echo -e "${YELLOW}自動ビルドは無効化されています${NC}"
        return 0
    fi

    echo -e "${MAGENTA}=== 自動ビルド起動 ===${NC}"

    local auto_build_cmd="$PROJECT_ROOT/scripts/auto-build-quarto.sh \"$WATCH_DIR\" --format $BUILD_FORMAT"

    echo -e "${GREEN}自動ビルドを起動中...${NC}"
    echo "監視ディレクトリ: $WATCH_DIR"
    echo "ビルド形式: $BUILD_FORMAT"

    # バックグラウンドで自動ビルドを起動
    cd "$PROJECT_ROOT"
    eval "$auto_build_cmd" &
    BUILD_PID=$!
    echo $BUILD_PID > "$BUILD_PID_FILE"

    echo -e "${GREEN}✓ 自動ビルドが起動しました (PID: $BUILD_PID)${NC}"

    # プロセスが正常に起動したかチェック
    sleep 2
    if ! kill -0 "$BUILD_PID" 2>/dev/null; then
        echo -e "${RED}エラー: 自動ビルドの起動に失敗しました${NC}"
        return 1
    fi
}

# 統合状況の表示
show_status() {
    echo ""
    echo -e "${BLUE}=== 開発サーバー統合環境 ===${NC}"
    echo ""
    echo -e "${CYAN}🌐 プレビューサーバー:${NC}"
    echo "    URL: http://localhost:$PREVIEW_PORT"
    echo "    ブラウザ自動オープン: $([ "$BROWSER_OPEN" = "true" ] && echo "有効" || echo "無効")"
    echo ""

    if [ "$ENABLE_AUTO_BUILD" = "true" ]; then
        echo -e "${MAGENTA}🔨 自動ビルド:${NC}"
        echo "    監視ディレクトリ: $WATCH_DIR"
        echo "    ビルド形式: $BUILD_FORMAT"
        echo "    監視ツール: $WATCH_TOOL"
        echo ""
    fi

    echo -e "${GREEN}📝 開発ワークフロー:${NC}"
    echo "    1. ブラウザでプレビューを確認"
    echo "    2. .qmdファイルを編集・保存"
    if [ "$ENABLE_AUTO_BUILD" = "true" ]; then
        echo "    3. 自動ビルド実行"
        echo "    4. プレビュー自動更新"
    else
        echo "    3. プレビュー自動更新"
    fi
    echo ""
    echo -e "${YELLOW}停止: Ctrl+C${NC}"
    echo ""
}

# ログ表示の開始
start_log_monitoring() {
    echo -e "${BLUE}=== ログ監視開始 ===${NC}"
    echo -e "${YELLOW}ファイル変更を監視中... (Ctrl+Cで停止)${NC}"
    echo ""

    # ログファイルを監視（存在する場合）
    local log_files=("$PROJECT_ROOT/auto-build-quarto.log")

    for log_file in "${log_files[@]}"; do
        if [ -f "$log_file" ]; then
            echo -e "${GREEN}ログ監視: $log_file${NC}"
            tail -f "$log_file" &
        fi
    done
}

# メイン処理
main() {
    echo -e "${BLUE}=== Quarto統合開発サーバー ===${NC}"
    echo ""

    # 引数の解析
    parse_arguments "$@"

    # 設定の表示
    echo "設定:"
    echo "  プレビューポート: $PREVIEW_PORT"
    echo "  自動ビルド: $([ "$ENABLE_AUTO_BUILD" = "true" ] && echo "有効" || echo "無効")"
    if [ "$ENABLE_AUTO_BUILD" = "true" ]; then
        echo "  ビルド形式: $BUILD_FORMAT"
        echo "  監視ディレクトリ: $WATCH_DIR"
    fi
    echo "  ブラウザ自動オープン: $([ "$BROWSER_OPEN" = "true" ] && echo "有効" || echo "無効")"
    echo ""

    # 重複実行のチェック
    check_duplicate

    # 依存関係のチェック
    check_dependencies

    # プロジェクト設定の確認
    check_project_setup

    # プレビューサーバーの起動
    if ! start_preview_server; then
        exit 1
    fi

    # 自動ビルドの起動
    if ! start_auto_build; then
        exit 1
    fi

    # 統合状況の表示
    show_status

    # メインループ（プロセス監視）
    while true; do
        # プレビューサーバーの監視
        if [ -f "$PREVIEW_PID_FILE" ]; then
            PREVIEW_PID=$(cat "$PREVIEW_PID_FILE")
            if ! kill -0 "$PREVIEW_PID" 2>/dev/null; then
                echo -e "${RED}警告: プレビューサーバーが停止しました${NC}"
                break
            fi
        fi

        # 自動ビルドの監視（有効な場合のみ）
        if [ "$ENABLE_AUTO_BUILD" = "true" ] && [ -f "$BUILD_PID_FILE" ]; then
            BUILD_PID=$(cat "$BUILD_PID_FILE")
            if ! kill -0 "$BUILD_PID" 2>/dev/null; then
                echo -e "${RED}警告: 自動ビルドプロセスが停止しました${NC}"
                break
            fi
        fi

        sleep 5
    done

    cleanup
}

# スクリプト実行
main "$@"