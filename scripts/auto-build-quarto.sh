#!/bin/bash

# Quarto自動ビルドスクリプト - ファイル監視による自動ビルド
# 使用法: ./auto-build-quarto.sh [watch_dir] [options]

set -e

# カラー出力の定義
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# プロジェクトルートディレクトリの取得
PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEFAULT_WATCH_DIR="$PROJECT_ROOT/reports"
QUARTO_CONFIG="$PROJECT_ROOT/_quarto.yml"

# デフォルト値の設定
WATCH_DIR=${1:-$DEFAULT_WATCH_DIR}
BUILD_SCRIPT="$PROJECT_ROOT/scripts/build-quarto.sh"
FORMAT="all"
DEBOUNCE_SECONDS=2

# ログファイル
LOG_FILE="$PROJECT_ROOT/auto-build-quarto.log"

# PIDファイル（重複実行防止）
PID_FILE="$PROJECT_ROOT/.auto-build-quarto.pid"

# 終了時のクリーンアップ
cleanup() {
    echo -e "\n${YELLOW}Quarto自動ビルドを停止中...${NC}"
    rm -f "$PID_FILE"
    exit 0
}

trap cleanup SIGINT SIGTERM

# 使用法の表示
show_usage() {
    cat << EOF
使用法: $0 [watch_dir] [options]

引数:
  watch_dir   : 監視するディレクトリ（デフォルト: reports/）

オプション:
  --format FORMAT    : 出力形式 (html, pdf, all) [デフォルト: all]
  --debounce SECONDS : ファイル変更後の遅延時間（秒） [デフォルト: 2]
  --help             : このヘルプを表示

監視対象ファイル:
  - *.qmd (Quartoマークダウン)
  - *.md (従来マークダウン)
  - _quarto.yml (設定ファイル)
  - *.bib (参考文献)
  - *.css, *.scss (スタイル)

操作:
  Ctrl+C : 自動ビルドを停止

機能:
  - Quartoファイルの変更を監視
  - 自動的にHTML/PDF生成
  - ライブプレビューとの併用可能
  - ビルド結果をログに記録

Quartoシステム特徴:
  - 統合された設定管理 (_quarto.yml)
  - 高速なビルド処理とライブプレビュー

例:
  $0                              # デフォルト設定で開始
  $0 reports/                     # 特定ディレクトリを監視
  $0 --format html                # HTML形式のみ生成
  $0 --debounce 5                 # 5秒の遅延設定

併用推奨:
  # 別ターミナルでプレビューサーバーも起動
  quarto preview

EOF
}

# 引数の解析
parse_arguments() {
    shift  # 最初の引数（watch_dir）をスキップ

    while [[ $# -gt 0 ]]; do
        case $1 in
            --format)
                FORMAT="$2"
                shift 2
                ;;
            --debounce)
                DEBOUNCE_SECONDS="$2"
                shift 2
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

# 重複実行のチェック
check_duplicate() {
    if [ -f "$PID_FILE" ]; then
        OLD_PID=$(cat "$PID_FILE")
        if kill -0 "$OLD_PID" 2>/dev/null; then
            echo -e "${RED}エラー: Quarto自動ビルドは既に実行中です (PID: $OLD_PID)${NC}"
            echo "停止するには: kill $OLD_PID"
            exit 1
        else
            rm -f "$PID_FILE"
        fi
    fi

    # 現在のPIDを記録
    echo $$ > "$PID_FILE"
}

# ディレクトリの存在確認
check_directories() {
    if [ ! -d "$WATCH_DIR" ]; then
        echo -e "${RED}エラー: 監視ディレクトリ '$WATCH_DIR' が見つかりません${NC}"
        exit 1
    fi

    # Quartoプロジェクトの確認
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
}

# 必要なツールの確認
check_dependencies() {
    local missing_tools=()

    # Quartoの確認
    if ! command -v quarto &> /dev/null; then
        missing_tools+=("quarto")
    fi

    # ファイル監視ツールの確認
    if command -v inotifywait &> /dev/null; then
        WATCH_TOOL="inotifywait"
    elif command -v fswatch &> /dev/null; then
        WATCH_TOOL="fswatch"
    else
        missing_tools+=("inotify-tools (Linux) または fswatch (macOS)")
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

# Quartoビルド実行関数
execute_quarto_build() {
    local file_path="$1"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    echo -e "\n${BLUE}[$timestamp] Quartoビルド開始: $file_path${NC}"
    echo "[$timestamp] Quarto build started: $file_path" >> "$LOG_FILE"

    local build_success=true
    local relative_path=$(realpath --relative-to="$PROJECT_ROOT" "$file_path")

    # Quartoビルドの実行
    echo -e "${GREEN}Quartoでビルド中...${NC}"

    local build_cmd=""
    if [[ "$file_path" =~ \.qmd$ ]]; then
        # .qmdファイルの場合
        build_cmd="quarto render \"$relative_path\" --to $FORMAT"
    elif [[ "$file_path" =~ \.md$ ]]; then
        # .mdファイルの場合（従来形式への後方互換性）
        echo -e "${YELLOW}  注意: .mdファイルが検出されました。.qmd形式への移行を推奨します${NC}"
        build_cmd="quarto render \"$relative_path\" --to $FORMAT"
    elif [[ "$file_path" =~ _quarto\.yml$ ]] || [[ "$file_path" =~ \.bib$ ]] || [[ "$file_path" =~ \.(css|scss)$ ]]; then
        # 設定ファイルや参考文献、スタイルファイルの場合はプロジェクト全体を再ビルド
        echo -e "${GREEN}設定ファイルが変更されました。プロジェクト全体を再ビルド中...${NC}"
        build_cmd="quarto render --to $FORMAT"
    else
        echo -e "${YELLOW}  警告: 不明なファイル形式です。プロジェクト全体をビルドします${NC}"
        build_cmd="quarto render --to $FORMAT"
    fi

    # ビルド実行
    cd "$PROJECT_ROOT"
    if eval $build_cmd 2>&1 | tee -a "$LOG_FILE"; then
        echo "  ✓ Quartoビルド: 成功"
        echo "[$timestamp] Quarto build: SUCCESS" >> "$LOG_FILE"

        # 出力ファイルの情報表示
        show_build_results "$file_path"
    else
        echo -e "${RED}  ✗ Quartoビルド: 失敗${NC}"
        echo "[$timestamp] Quarto build: FAILED" >> "$LOG_FILE"
        build_success=false
    fi

    if $build_success; then
        echo -e "${GREEN}[$timestamp] ビルド完了: $file_path${NC}"
        echo "[$timestamp] Build completed: $file_path" >> "$LOG_FILE"
    else
        echo -e "${RED}[$timestamp] ビルド失敗: $file_path${NC}"
        echo "[$timestamp] Build failed: $file_path" >> "$LOG_FILE"
    fi
}

# ビルド結果の表示
show_build_results() {
    local source_file="$1"
    local output_found=false

    # 出力ディレクトリの確認
    local output_dirs=("$PROJECT_ROOT/output" "$PROJECT_ROOT/_site")

    for dir in "${output_dirs[@]}"; do
        if [ -d "$dir" ]; then
            local recent_files=$(find "$dir" -name "*.html" -o -name "*.pdf" -newer "$PID_FILE" 2>/dev/null | head -3)
            if [ -n "$recent_files" ]; then
                echo "  生成されたファイル:"
                echo "$recent_files" | while read file; do
                    local size=$(du -h "$file" | cut -f1)
                    echo "    - $(basename "$file") ($size)"
                done
                output_found=true
            fi
        fi
    done

    if [ "$output_found" = "false" ]; then
        echo "  注意: 新しい出力ファイルが見つかりませんでした"
    fi
}

# ファイル監視の開始
start_watching() {
    echo -e "${GREEN}=== Quarto自動ビルド開始 ===${NC}"
    echo "監視ディレクトリ: $WATCH_DIR"
    echo "出力形式: $FORMAT"
    echo "遅延時間: ${DEBOUNCE_SECONDS}秒"
    echo "PIDファイル: $PID_FILE"
    echo "ログファイル: $LOG_FILE"
    echo ""
    echo -e "${YELLOW}Quartoファイルの変更を監視中... (Ctrl+Cで停止)${NC}"
    echo -e "${BLUE}💡 ヒント: 別ターミナルで 'quarto preview' も実行すると便利です${NC}"
    echo ""

    if [ "$WATCH_TOOL" = "inotifywait" ]; then
        # Linux (inotify)
        inotifywait -m -r -e close_write,moved_to --format '%w%f' "$WATCH_DIR" "$PROJECT_ROOT/_quarto.yml" "$PROJECT_ROOT/sources/references/" "$PROJECT_ROOT/reports/templates/styles/" 2>/dev/null |
        while read file; do
            if [[ "$file" =~ \.(qmd|md|yml|yaml|bib|css|scss)$ ]]; then
                # デバウンス処理
                sleep "$DEBOUNCE_SECONDS"
                execute_quarto_build "$file"
            fi
        done
    elif [ "$WATCH_TOOL" = "fswatch" ]; then
        # macOS (fswatch)
        fswatch -o "$WATCH_DIR" "$PROJECT_ROOT/_quarto.yml" "$PROJECT_ROOT/sources/references/" "$PROJECT_ROOT/reports/templates/styles/" |
        while read num; do
            # 変更されたファイルを検索
            find "$WATCH_DIR" "$PROJECT_ROOT" -name "*.qmd" -o -name "*.md" -o -name "_quarto.yml" -o -name "*.bib" -o -name "*.css" -o -name "*.scss" -newer "$PID_FILE" -type f 2>/dev/null |
            while read file; do
                # デバウンス処理
                sleep "$DEBOUNCE_SECONDS"
                execute_quarto_build "$file"
            done
            # PIDファイルのタイムスタンプを更新
            touch "$PID_FILE"
        done
    fi
}

# Quartoシステム案内表示
show_quarto_workflow() {
    echo -e "${BLUE}=== Quartoワークフロー ===${NC}"
    echo ""
    echo "✨ 主要機能:"
    echo "  - 統合されたプレビューサーバー (quarto preview)"
    echo "  - 自動相互参照とリンク生成"
    echo "  - リアルタイムな目次更新"
    echo "  - 美しいデフォルトテーマ"
    echo "  - 設定ファイル監視による全体再ビルド"
    echo ""
    echo "🔄 推奨ワークフロー:"
    echo "  1. ターミナル1: quarto preview (プレビューサーバー)"
    echo "  2. ターミナル2: $0 (自動ビルド)"
    echo "  3. エディタで .qmd ファイルを編集"
    echo "  → 自動でビルド + プレビュー更新"
    echo ""
}

# メイン処理
main() {
    echo -e "${BLUE}=== Quarto自動ビルドシステム ===${NC}"

    # 引数の解析
    parse_arguments "$@"

    # 重複実行のチェック
    check_duplicate

    # ディレクトリと設定の確認
    check_directories

    # 依存関係のチェック
    check_dependencies

    # 初回利用時の案内
    if [ ! -f "$PROJECT_ROOT/.quarto_auto_build_intro_shown" ]; then
        show_quarto_workflow
        touch "$PROJECT_ROOT/.quarto_auto_build_intro_shown"
        echo ""
    fi

    # 初期ビルド（オプション）
    read -p "開始前に既存のQuartoファイルをビルドしますか？ (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${GREEN}初期ビルドを実行中...${NC}"
        cd "$PROJECT_ROOT"
        quarto render --to "$FORMAT"
    fi

    # ファイル監視の開始
    start_watching
}

# スクリプト実行
main "$@"