#!/bin/bash

# Quartoビルドスクリプト - pandocベースシステムの簡素化版
# 使用法: ./build-quarto.sh [options] [target]

set -e

# カラー出力の定義
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# プロジェクトルートディレクトリ
PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
QUARTO_CONFIG="$PROJECT_ROOT/_quarto.yml"

# デフォルト設定
TARGET=""
FORMAT="all"
PREVIEW=false
CLEAN=false
PROFILE=""
VERBOSE=false

# 使用法の表示
show_usage() {
    cat << EOF
使用法: $0 [options] [target]

引数:
  target              : ビルド対象（省略時は全体をビルド）
                       - project: プロジェクト全体
                       - file.qmd: 特定のファイル
                       - reports/: 特定のディレクトリ

オプション:
  --format FORMAT     : 出力形式 (html, pdf, all) [デフォルト: all]
  --preview           : プレビューサーバーを起動
  --clean             : 出力ディレクトリをクリーン
  --profile PROFILE   : ビルドプロファイルを指定
  --verbose           : 詳細出力
  --help              : このヘルプを表示

便利な操作:
  --check             : Quartoの動作確認
  --setup             : 初回セットアップ

例:
  $0                              # 全体をビルド
  $0 --format html                # HTML形式のみ
  $0 --preview                    # プレビューサーバー起動
  $0 reports/my-report.qmd        # 特定ファイルをビルド
  $0 --clean                      # 出力をクリーン
  $0 --check                      # 動作確認

従来のpandocスクリプトとの比較:
  従来: scripts/build-report.sh html reports/report.md
  Quarto: $0 reports/report.qmd --format html

EOF
}

# 引数の解析
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --format)
                FORMAT="$2"
                shift 2
                ;;
            --preview)
                PREVIEW=true
                shift
                ;;
            --clean)
                CLEAN=true
                shift
                ;;
            --profile)
                PROFILE="$2"
                shift 2
                ;;
            --verbose)
                VERBOSE=true
                shift
                ;;
            --check)
                check_quarto
                exit 0
                ;;
            --setup)
                setup_project
                exit 0
                ;;
            --help)
                show_usage
                exit 0
                ;;
            --*)
                echo -e "${RED}エラー: 不明なオプション '$1'${NC}"
                show_usage
                exit 1
                ;;
            *)
                TARGET="$1"
                shift
                ;;
        esac
    done
}

# Quartoの動作確認
check_quarto() {
    echo -e "${BLUE}=== Quarto動作確認 ===${NC}"

    if ! command -v quarto &> /dev/null; then
        echo -e "${RED}エラー: Quartoがインストールされていません${NC}"
        echo "インストール方法:"
        echo "  scripts/setup-quarto.sh"
        exit 1
    fi

    local version=$(quarto --version)
    echo -e "${GREEN}✓ Quarto $version がインストールされています${NC}"

    echo -e "${GREEN}Quartoの設定を確認中...${NC}"
    quarto check

    if [ -f "$QUARTO_CONFIG" ]; then
        echo -e "${GREEN}✓ プロジェクト設定ファイルが見つかりました${NC}"
    else
        echo -e "${YELLOW}警告: _quarto.yml が見つかりません${NC}"
        echo "セットアップを実行してください: $0 --setup"
    fi

    echo -e "${GREEN}✓ Quartoの動作確認が完了しました${NC}"
}

# プロジェクトセットアップ
setup_project() {
    echo -e "${BLUE}=== Quartoプロジェクトセットアップ ===${NC}"

    if [ ! -f "$QUARTO_CONFIG" ]; then
        echo -e "${GREEN}_quarto.yml を作成中...${NC}"
        scripts/setup-quarto.sh
    else
        echo -e "${GREEN}_quarto.yml は既に存在します${NC}"
    fi

    # サンプルレポートの作成
    local sample_report="$PROJECT_ROOT/reports/sample-report.qmd"
    if [ ! -f "$sample_report" ]; then
        echo -e "${GREEN}サンプルレポートを作成中...${NC}"
        cp "$PROJECT_ROOT/reports/templates/report_template.qmd" "$sample_report"

        # タイトルを変更
        sed -i 's/調査報告書タイトル/サンプル調査報告書/' "$sample_report"

        echo -e "${GREEN}✓ サンプルレポートを作成: $sample_report${NC}"
    fi

    echo -e "${GREEN}✓ セットアップが完了しました${NC}"
    echo ""
    echo "次のステップ:"
    echo "  1. quarto preview でプレビューを開始"
    echo "  2. reports/ フォルダに .qmd ファイルを作成"
    echo "  3. $0 でビルドを実行"
}

# 出力ディレクトリのクリーン
clean_output() {
    echo -e "${GREEN}出力ディレクトリをクリーン中...${NC}"

    local output_dirs=("$PROJECT_ROOT/output" "$PROJECT_ROOT/_site" "$PROJECT_ROOT/.quarto")

    for dir in "${output_dirs[@]}"; do
        if [ -d "$dir" ]; then
            rm -rf "$dir"
            echo "  ✓ $dir を削除"
        fi
    done

    echo -e "${GREEN}✓ クリーンが完了しました${NC}"
}

# フォーマット検証
validate_format() {
    case $FORMAT in
        html|pdf|all)
            return 0
            ;;
        *)
            echo -e "${RED}エラー: 不正な出力形式 '$FORMAT'${NC}"
            echo "有効な形式: html, pdf, all"
            exit 1
            ;;
    esac
}

# ビルド実行
execute_build() {
    echo -e "${BLUE}=== Quartoビルド実行 ===${NC}"

    # 基本的なQuartoコマンドの構築
    local cmd="quarto render"

    # ターゲットの指定
    if [ -n "$TARGET" ]; then
        cmd="$cmd \"$TARGET\""
    fi

    # フォーマットの指定
    if [ "$FORMAT" != "all" ]; then
        cmd="$cmd --to $FORMAT"
    fi

    # プロファイルの指定
    if [ -n "$PROFILE" ]; then
        cmd="$cmd --profile $PROFILE"
    fi

    # 詳細出力
    if [ "$VERBOSE" = "true" ]; then
        cmd="$cmd --verbose"
    fi

    echo -e "${GREEN}実行コマンド: $cmd${NC}"
    echo ""

    # ビルド実行
    cd "$PROJECT_ROOT"

    if eval $cmd; then
        echo ""
        echo -e "${GREEN}✓ ビルドが正常に完了しました${NC}"

        # 出力ファイルの情報表示
        show_output_info

        return 0
    else
        echo ""
        echo -e "${RED}✗ ビルドが失敗しました${NC}"
        return 1
    fi
}

# 出力ファイル情報の表示
show_output_info() {
    echo -e "${BLUE}=== 出力ファイル ===${NC}"

    local output_dirs=("$PROJECT_ROOT/output" "$PROJECT_ROOT/_site")

    for dir in "${output_dirs[@]}"; do
        if [ -d "$dir" ]; then
            echo -e "${GREEN}出力ディレクトリ: $dir${NC}"

            # HTMLファイル
            local html_files=$(find "$dir" -name "*.html" -type f 2>/dev/null | head -5)
            if [ -n "$html_files" ]; then
                echo "  HTML:"
                echo "$html_files" | while read file; do
                    local size=$(du -h "$file" | cut -f1)
                    echo "    - $(basename "$file") ($size)"
                done
            fi

            # PDFファイル
            local pdf_files=$(find "$dir" -name "*.pdf" -type f 2>/dev/null | head -5)
            if [ -n "$pdf_files" ]; then
                echo "  PDF:"
                echo "$pdf_files" | while read file; do
                    local size=$(du -h "$file" | cut -f1)
                    echo "    - $(basename "$file") ($size)"
                done
            fi

            echo ""
        fi
    done

    # ブラウザで開くか確認（HTMLの場合）
    if [ "$FORMAT" = "html" ] || [ "$FORMAT" = "all" ]; then
        local main_html=$(find "$PROJECT_ROOT" -name "index.html" -o -name "*.html" | head -1)
        if [ -n "$main_html" ]; then
            read -p "ブラウザで開きますか？ (y/N): " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                open_in_browser "$main_html"
            fi
        fi
    fi
}

# ブラウザで開く
open_in_browser() {
    local file="$1"

    if command -v xdg-open &> /dev/null; then
        xdg-open "$file"
    elif command -v open &> /dev/null; then
        open "$file"
    else
        echo -e "${YELLOW}ブラウザを自動で開けませんでした${NC}"
        echo "手動で開いてください: $file"
    fi
}

# プレビューサーバー起動
start_preview() {
    echo -e "${BLUE}=== Quartoプレビューサーバー起動 ===${NC}"

    cd "$PROJECT_ROOT"

    local cmd="quarto preview"

    # ターゲットの指定
    if [ -n "$TARGET" ]; then
        cmd="$cmd \"$TARGET\""
    fi

    # ポートの指定（既に使用されている場合は自動で変更）
    cmd="$cmd --port 3000"

    echo -e "${GREEN}プレビューサーバーを起動中...${NC}"
    echo -e "${YELLOW}Ctrl+C で停止${NC}"
    echo ""

    eval $cmd
}

# Quartoシステム情報表示
show_quarto_info() {
    echo -e "${BLUE}=== Quartoシステム情報 ===${NC}"
    echo ""
    echo "✨ 主要機能:"
    echo "  - 自動相互参照 (@fig-chart, @tbl-data)"
    echo "  - ビルトイン引用管理 (.bib ファイル)"
    echo "  - リアルタイムプレビュー"
    echo "  - 美しいデフォルトテーマ"
    echo "  - マルチフォーマット一括出力"
    echo ""
    echo "🚀 基本操作:"
    echo "  - quarto render: 全形式ビルド"
    echo "  - quarto preview: ライブプレビュー"
    echo "  - scripts/build-quarto.sh: 統合ビルドツール"
    echo ""
}

# メイン処理
main() {
    echo -e "${BLUE}=== Quartoビルドシステム ===${NC}"

    # 引数の解析
    parse_arguments "$@"

    # 設定の表示
    if [ "$VERBOSE" = "true" ]; then
        echo "設定:"
        echo "  ターゲット: ${TARGET:-"プロジェクト全体"}"
        echo "  形式: $FORMAT"
        echo "  プレビュー: $PREVIEW"
        echo "  クリーン: $CLEAN"
        echo ""
    fi

    # Quartoの確認
    if ! command -v quarto &> /dev/null; then
        echo -e "${RED}エラー: Quartoがインストールされていません${NC}"
        echo "以下のコマンドでインストールしてください:"
        echo "  scripts/setup-quarto.sh"
        exit 1
    fi

    # プロジェクト設定の確認
    if [ ! -f "$QUARTO_CONFIG" ]; then
        echo -e "${YELLOW}警告: _quarto.yml が見つかりません${NC}"
        read -p "セットアップを実行しますか？ (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            setup_project
        else
            echo "セットアップをスキップします"
        fi
    fi

    # クリーン実行
    if [ "$CLEAN" = "true" ]; then
        clean_output
        if [ "$PREVIEW" = "false" ] && [ -z "$TARGET" ]; then
            echo "クリーンのみ実行しました"
            exit 0
        fi
    fi

    # フォーマット検証
    validate_format

    # プレビューサーバー起動
    if [ "$PREVIEW" = "true" ]; then
        start_preview
        exit 0
    fi

    # ビルド実行
    if ! execute_build; then
        exit 1
    fi

    # Quartoシステム情報（初回のみ）
    if [ ! -f "$PROJECT_ROOT/.quarto_info_shown" ]; then
        echo ""
        show_quarto_info
        touch "$PROJECT_ROOT/.quarto_info_shown"
    fi

    echo -e "${GREEN}=== ビルド完了 ===${NC}"
}

# スクリプト実行
main "$@"