#!/bin/bash

# ResearchTemplate 環境セットアップスクリプト
# Usage: bash <(curl -fsSL https://raw.githubusercontent.com/dobachi/ResearchTemplate/main/scripts/setup.sh)
# または: ./scripts/setup.sh

set -euo pipefail

# 色付きアウトプット用
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# ログ用関数
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# OS検出
detect_os() {
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        if [ -f /etc/debian_version ]; then
            echo "debian"
        elif [ -f /etc/redhat-release ]; then
            echo "redhat"
        else
            echo "linux"
        fi
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        echo "macos"
    else
        echo "unknown"
    fi
}

# sudoコマンドの確認
check_sudo() {
    if ! sudo -n true 2>/dev/null; then
        log_warning "一部の操作にsudo権限が必要です"
        sudo -v
    fi
}

# Git submoduleの初期化
setup_submodules() {
    log_info "Git submoduleを初期化しています..."

    if [ -f .gitmodules ]; then
        git submodule update --init --recursive
        log_success "Git submoduleの初期化が完了しました"
    else
        log_warning ".gitmodulesが見つかりません。スキップします。"
    fi
}

# Quartoのインストール
install_quarto() {
    log_info "Quartoをインストールしています..."

    if command -v quarto &> /dev/null; then
        local current_version=$(quarto --version)
        log_success "Quartoは既にインストールされています (version: $current_version)"
        return
    fi

    local os=$(detect_os)
    local quarto_version="1.4.549"

    case $os in
        debian)
            log_info "Debian/Ubuntu用Quartoをインストールします..."
            local temp_deb="/tmp/quarto-${quarto_version}-linux-amd64.deb"
            wget -O "$temp_deb" "https://github.com/quarto-dev/quarto-cli/releases/download/v${quarto_version}/quarto-${quarto_version}-linux-amd64.deb"
            sudo dpkg -i "$temp_deb"
            rm "$temp_deb"
            ;;
        redhat)
            log_info "RedHat/Fedora用Quartoをインストールします..."
            local temp_rpm="/tmp/quarto-${quarto_version}-linux-amd64.rpm"
            wget -O "$temp_rpm" "https://github.com/quarto-dev/quarto-cli/releases/download/v${quarto_version}/quarto-${quarto_version}-linux-amd64.rpm"
            sudo rpm -i "$temp_rpm"
            rm "$temp_rpm"
            ;;
        macos)
            log_info "macOS用Quartoをインストールします..."
            if command -v brew &> /dev/null; then
                brew install quarto
            else
                log_error "Homebrewがインストールされていません。手動でQuartoをインストールしてください: https://quarto.org/docs/get-started/"
                return 1
            fi
            ;;
        *)
            log_error "サポートされていないOSです。手動でQuartoをインストールしてください: https://quarto.org/docs/get-started/"
            return 1
            ;;
    esac

    log_success "Quartoのインストールが完了しました"
}

# 日本語LaTeX環境のセットアップ
setup_japanese_latex() {
    log_info "日本語LaTeX環境をセットアップしています..."

    local os=$(detect_os)

    case $os in
        debian)
            log_info "TeX Live（日本語対応）をインストールします..."
            sudo apt-get update
            sudo apt-get install -y \
                texlive-base \
                texlive-latex-base \
                texlive-latex-recommended \
                texlive-latex-extra \
                texlive-fonts-recommended \
                texlive-fonts-extra \
                texlive-lang-japanese \
                texlive-luatex \
                texlive-xetex \
                lmodern \
                fonts-noto-cjk \
                fonts-noto-cjk-extra

            # LaTeXfontsのキャッシュ更新
            sudo mktexlsr
            sudo kanji-config-updmap-sys auto

            log_success "日本語LaTeX環境のセットアップが完了しました"
            ;;
        redhat)
            log_info "TeX Live（日本語対応）をインストールします..."
            sudo dnf install -y \
                texlive-scheme-basic \
                texlive-collection-latex \
                texlive-collection-latexrecommended \
                texlive-collection-latexextra \
                texlive-collection-fontsrecommended \
                texlive-collection-fontsextra \
                texlive-collection-langjapanese \
                google-noto-cjk-fonts

            log_success "日本語LaTeX環境のセットアップが完了しました"
            ;;
        macos)
            log_info "MacTeX（日本語対応）をインストールします..."
            if command -v brew &> /dev/null; then
                brew install --cask mactex-no-gui

                # PATHの追加
                if [[ ! "$PATH" == */usr/local/texlive/*/bin/* ]]; then
                    log_info "TeXのパスを追加しています..."
                    echo 'export PATH="/usr/local/texlive/2023/bin/universal-darwin:$PATH"' >> ~/.zshrc
                    export PATH="/usr/local/texlive/2023/bin/universal-darwin:$PATH"
                fi

                log_success "日本語LaTeX環境のセットアップが完了しました"
            else
                log_error "Homebrewがインストールされていません"
                return 1
            fi
            ;;
        *)
            log_error "サポートされていないOSです"
            return 1
            ;;
    esac
}

# Pandocのインストール
install_pandoc() {
    log_info "Pandocをチェックしています..."

    if command -v pandoc &> /dev/null; then
        local current_version=$(pandoc --version | head -1)
        log_success "Pandocは既にインストールされています ($current_version)"
        return
    fi

    local os=$(detect_os)

    case $os in
        debian)
            log_info "Pandocをインストールします..."
            sudo apt-get update
            sudo apt-get install -y pandoc pandoc-citeproc
            ;;
        redhat)
            log_info "Pandocをインストールします..."
            sudo dnf install -y pandoc
            ;;
        macos)
            log_info "Pandocをインストールします..."
            if command -v brew &> /dev/null; then
                brew install pandoc
            else
                log_error "Homebrewがインストールされていません"
                return 1
            fi
            ;;
        *)
            log_error "サポートされていないOSです"
            return 1
            ;;
    esac

    log_success "Pandocのインストールが完了しました"
}

# その他の依存パッケージのインストール
install_dependencies() {
    log_info "その他の依存パッケージをインストールしています..."

    local os=$(detect_os)

    case $os in
        debian)
            sudo apt-get install -y \
                curl \
                wget \
                git \
                make
            ;;
        redhat)
            sudo dnf install -y \
                curl \
                wget \
                git \
                make
            ;;
        macos)
            if command -v brew &> /dev/null; then
                brew install curl wget git make
            fi
            ;;
    esac

    log_success "依存パッケージのインストールが完了しました"
}

# 環境確認
verify_installation() {
    log_info "インストール確認を実行しています..."

    local all_ok=true

    # Git
    if command -v git &> /dev/null; then
        log_success "Git: $(git --version)"
    else
        log_error "Git: インストールされていません"
        all_ok=false
    fi

    # Pandoc
    if command -v pandoc &> /dev/null; then
        log_success "Pandoc: $(pandoc --version | head -1)"
    else
        log_error "Pandoc: インストールされていません"
        all_ok=false
    fi

    # Quarto
    if command -v quarto &> /dev/null; then
        log_success "Quarto: $(quarto --version)"
    else
        log_warning "Quarto: インストールされていません"
    fi

    # LaTeX
    if command -v pdflatex &> /dev/null; then
        log_success "pdfLaTeX: $(pdflatex --version | head -1)"
    elif command -v lualatex &> /dev/null; then
        log_success "LuaLaTeX: $(lualatex --version | head -1)"
    else
        log_warning "LaTeX: インストールされていません"
    fi

    echo ""
    if [ "$all_ok" = true ]; then
        log_success "すべての必須パッケージがインストールされています"
    else
        log_error "一部のパッケージがインストールされていません"
        return 1
    fi
}

# メイン処理
main() {
    echo ""
    echo "=========================================="
    echo "  ResearchTemplate セットアップスクリプト"
    echo "=========================================="
    echo ""

    log_info "OS: $(detect_os)"
    echo ""

    # sudo権限の確認
    check_sudo

    # 依存パッケージのインストール
    install_dependencies

    # Pandocのインストール
    install_pandoc

    # Quartoのインストール
    read -p "Quartoをインストールしますか？ (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        install_quarto
    else
        log_info "Quartoのインストールをスキップしました"
    fi

    # 日本語LaTeX環境のセットアップ
    read -p "日本語LaTeX環境をセットアップしますか？ (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        setup_japanese_latex
    else
        log_info "日本語LaTeX環境のセットアップをスキップしました"
    fi

    # Git submoduleの初期化
    if [ -d .git ]; then
        setup_submodules
    else
        log_warning ".gitディレクトリが見つかりません。submoduleの初期化をスキップします"
    fi

    echo ""
    echo "=========================================="
    echo "  インストール確認"
    echo "=========================================="
    echo ""

    verify_installation

    echo ""
    echo "=========================================="
    echo "  セットアップ完了"
    echo "=========================================="
    echo ""

    log_success "環境セットアップが完了しました"
    echo ""
    echo "次のステップ:"
    echo "  1. プロジェクト設定を確認: cat instructions/PROJECT.md"
    echo "  2. 報告書テンプレートを確認: cat reports/templates/report_template.md"
    echo "  3. HTMLレポートを生成: scripts/build-report.sh html reports/samples/sample_ai_regulation.md"
    echo "  4. PDFレポートを生成: scripts/build-report.sh pdf reports/samples/sample_ai_regulation.md"
    echo ""
}

# スクリプト実行
main "$@"
