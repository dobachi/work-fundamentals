#!/bin/bash

# Quartoセットアップスクリプト
# 使用法: ./setup-quarto.sh [--force] [--version VERSION]

set -e

# カラー出力の定義
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# デフォルト設定
QUARTO_VERSION="latest"
FORCE_INSTALL=false

# 引数の解析
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --force)
                FORCE_INSTALL=true
                shift
                ;;
            --version)
                QUARTO_VERSION="$2"
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

# 使用法の表示
show_usage() {
    cat << EOF
使用法: $0 [options]

オプション:
  --force          : 既存のQuartoがある場合も強制的に再インストール
  --version VERSION: 特定のバージョンを指定（デフォルト: latest）
  --help           : このヘルプを表示

説明:
  このスクリプトはQuartoをインストールし、プロジェクトをQuarto対応に設定します。

対応OS:
  - Linux (Ubuntu/Debian)
  - macOS
  - Windows (WSL)

必要な依存関係も自動でインストールされます:
  - pandoc
  - wkhtmltopdf
  - texlive (PDF生成用)

例:
  $0                    # 最新版をインストール
  $0 --force            # 強制再インストール
  $0 --version 1.4.550  # 特定バージョンをインストール

EOF
}

# OS検出
detect_os() {
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        if command -v apt-get &> /dev/null; then
            OS="ubuntu"
            PACKAGE_MANAGER="apt-get"
        elif command -v yum &> /dev/null; then
            OS="rhel"
            PACKAGE_MANAGER="yum"
        else
            OS="linux"
            PACKAGE_MANAGER=""
        fi
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        OS="macos"
        PACKAGE_MANAGER="brew"
    elif [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "cygwin" ]]; then
        OS="windows"
        PACKAGE_MANAGER=""
    else
        OS="unknown"
        PACKAGE_MANAGER=""
    fi

    echo -e "${BLUE}検出されたOS: $OS${NC}"
}

# Quartoの存在確認
check_quarto_installation() {
    if command -v quarto &> /dev/null; then
        CURRENT_VERSION=$(quarto --version 2>/dev/null || echo "unknown")
        echo -e "${GREEN}Quarto $CURRENT_VERSION が既にインストールされています${NC}"

        if [ "$FORCE_INSTALL" = "false" ]; then
            read -p "再インストールしますか？ (y/N): " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                echo "インストールをスキップします"
                return 1
            fi
        fi
    fi
    return 0
}

# 依存関係のインストール
install_dependencies() {
    echo -e "${GREEN}依存関係をインストール中...${NC}"

    case $OS in
        ubuntu)
            sudo apt-get update
            sudo apt-get install -y curl gdebi-core

            # pandocとwkhtmltopdfのインストール
            sudo apt-get install -y pandoc wkhtmltopdf

            # LaTeX環境のインストール（PDF生成用）
            sudo apt-get install -y texlive-latex-base texlive-fonts-recommended texlive-fonts-extra texlive-latex-extra
            ;;
        macos)
            if ! command -v brew &> /dev/null; then
                echo -e "${RED}エラー: Homebrewがインストールされていません${NC}"
                echo "以下のコマンドでHomebrewをインストールしてください:"
                echo '/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"'
                exit 1
            fi

            brew install pandoc wkhtmltopdf

            # MacTeX（LaTeX）のインストール確認
            if ! command -v pdflatex &> /dev/null; then
                echo -e "${YELLOW}MacTeX（LaTeX）が見つかりません。PDF生成には必要です。${NC}"
                echo "以下のコマンドでインストールできます:"
                echo "brew install mactex"
            fi
            ;;
        *)
            echo -e "${YELLOW}警告: 自動的な依存関係のインストールは$OSでは対応していません${NC}"
            echo "手動で以下をインストールしてください:"
            echo "- pandoc"
            echo "- wkhtmltopdf"
            echo "- LaTeX環境"
            ;;
    esac
}

# Quartoのダウンロードとインストール
install_quarto() {
    echo -e "${GREEN}Quartoをインストール中...${NC}"

    # 一時ディレクトリの作成
    TEMP_DIR=$(mktemp -d)
    cd "$TEMP_DIR"

    case $OS in
        ubuntu)
            # Linux版Quartoのダウンロード
            if [ "$QUARTO_VERSION" = "latest" ]; then
                DOWNLOAD_URL="https://github.com/quarto-dev/quarto-cli/releases/latest/download/quarto-linux-amd64.deb"
            else
                DOWNLOAD_URL="https://github.com/quarto-dev/quarto-cli/releases/download/v${QUARTO_VERSION}/quarto-${QUARTO_VERSION}-linux-amd64.deb"
            fi

            echo "ダウンロード中: $DOWNLOAD_URL"
            curl -LO "$DOWNLOAD_URL"

            # .debパッケージのインストール
            sudo gdebi --non-interactive quarto-*.deb
            ;;
        macos)
            # macOS版Quartoのダウンロード
            if [ "$QUARTO_VERSION" = "latest" ]; then
                DOWNLOAD_URL="https://github.com/quarto-dev/quarto-cli/releases/latest/download/quarto-macos.pkg"
            else
                DOWNLOAD_URL="https://github.com/quarto-dev/quarto-cli/releases/download/v${QUARTO_VERSION}/quarto-${QUARTO_VERSION}-macos.pkg"
            fi

            echo "ダウンロード中: $DOWNLOAD_URL"
            curl -LO "$DOWNLOAD_URL"

            # .pkgのインストール
            sudo installer -pkg quarto-*.pkg -target /
            ;;
        *)
            echo -e "${RED}エラー: $OS での自動インストールは対応していません${NC}"
            echo "手動でQuartoをインストールしてください: https://quarto.org/docs/get-started/"
            exit 1
            ;;
    esac

    # 一時ディレクトリの削除
    cd - > /dev/null
    rm -rf "$TEMP_DIR"
}

# インストール確認
verify_installation() {
    echo -e "${GREEN}インストールを確認中...${NC}"

    if command -v quarto &> /dev/null; then
        INSTALLED_VERSION=$(quarto --version)
        echo -e "${GREEN}✓ Quarto $INSTALLED_VERSION が正常にインストールされました${NC}"

        # 基本機能のテスト
        echo -e "${GREEN}基本機能をテスト中...${NC}"
        quarto check

        echo -e "${GREEN}✓ Quartoの基本機能が正常に動作しています${NC}"
    else
        echo -e "${RED}✗ Quartoのインストールに失敗しました${NC}"
        exit 1
    fi
}

# プロジェクト設定の更新
setup_project() {
    echo -e "${GREEN}プロジェクト設定を更新中...${NC}"

    # Quartoプロジェクト設定ファイルの作成
    PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

    cat > "$PROJECT_ROOT/_quarto.yml" << 'EOF'
project:
  type: book
  output-dir: output

book:
  title: "調査報告書"
  subtitle: "Research Report"
  author: "研究者名"
  date: today

  chapters:
    - index.qmd

  sidebar:
    title: "調査報告書"
    collapse-level: 1

format:
  html:
    theme:
      - journal
      - reports/templates/styles/custom.scss
    toc: true
    toc-depth: 3
    toc-location: left
    number-sections: true
    code-fold: true
    css: reports/templates/styles/report-style.css

  pdf:
    documentclass: scrbook
    toc: true
    toc-depth: 3
    number-sections: true
    geometry:
      - margin=2cm
    lang: ja
    pdf-engine: xelatex
    mainfont: "Noto Sans CJK JP"

bibliography: sources/references/bibliography.bib
csl: reports/templates/styles/apa.csl

crossref:
  fig-title: "図"
  tbl-title: "表"
  title-delim: ":"
  fig-prefix: "図"
  tbl-prefix: "表"
EOF

    echo -e "${GREEN}✓ _quarto.yml を作成しました${NC}"

    # .gitignoreの更新
    if [ -f "$PROJECT_ROOT/.gitignore" ]; then
        if ! grep -q "_site/" "$PROJECT_ROOT/.gitignore"; then
            echo "" >> "$PROJECT_ROOT/.gitignore"
            echo "# Quarto" >> "$PROJECT_ROOT/.gitignore"
            echo "_site/" >> "$PROJECT_ROOT/.gitignore"
            echo ".quarto/" >> "$PROJECT_ROOT/.gitignore"
            echo -e "${GREEN}✓ .gitignore を更新しました${NC}"
        fi
    fi
}

# メイン処理
main() {
    echo -e "${BLUE}=== Quartoセットアップスクリプト ===${NC}"

    # 引数の解析
    parse_arguments "$@"

    # OS検出
    detect_os

    # 既存インストールの確認
    if ! check_quarto_installation; then
        echo "セットアップを完了します"
        setup_project
        echo -e "${GREEN}=== セットアップ完了 ===${NC}"
        return 0
    fi

    # 依存関係のインストール
    install_dependencies

    # Quartoのインストール
    install_quarto

    # インストール確認
    verify_installation

    # プロジェクト設定
    setup_project

    echo -e "${GREEN}=== Quartoセットアップ完了 ===${NC}"
    echo ""
    echo "次のステップ:"
    echo "1. scripts/build-quarto.sh でレポートをビルド"
    echo "2. quarto preview でライブプレビューを開始"
    echo "3. reports/ フォルダに .qmd ファイルを作成"
}

# スクリプト実行
main "$@"