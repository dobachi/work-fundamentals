#!/bin/bash

# 調査報告書プロジェクト作成スクリプト
# Usage: bash <(curl -fsSL https://raw.githubusercontent.com/dobachi/ResearchTemplate/main/scripts/create-project.sh) PROJECT_NAME

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

# 前提条件チェック
check_prerequisites() {
    log_info "前提条件をチェックしています..."

    if ! command -v git >/dev/null 2>&1; then
        log_error "Gitがインストールされていません"
        exit 1
    fi

    if ! command -v gh >/dev/null 2>&1; then
        log_error "GitHub CLI (gh) がインストールされていません"
        log_info "インストール方法: https://cli.github.com/"
        exit 1
    fi

    # GitHub CLI の認証チェック
    if ! gh auth status >/dev/null 2>&1; then
        log_error "GitHub CLI が認証されていません"
        log_info "認証コマンド: gh auth login"
        exit 1
    fi

    log_success "前提条件をクリアしました"
}

# 使用方法
usage() {
    echo "使用方法: $0 PROJECT_NAME"
    echo ""
    echo "例:"
    echo "  $0 my-research-project"
    echo ""
    echo "このスクリプトは以下を実行します:"
    echo "  1. 新しいプロジェクトディレクトリを作成"
    echo "  2. ResearchTemplateをクローン"
    echo "  3. GitHubにプライベートリポジトリを作成"
    echo "  4. 新しいリポジトリにプッシュ"
    echo "  5. サブモジュールを初期化"
    exit 1
}

# メイン処理
main() {
    local project_name="$1"
    local template_repo="https://github.com/dobachi/ResearchTemplate.git"
    local current_dir=$(pwd)

    log_info "プロジェクト '${project_name}' を作成開始..."

    # 1. プロジェクトディレクトリが既に存在しないかチェック
    if [ -d "$project_name" ]; then
        log_error "ディレクトリ '${project_name}' は既に存在します"
        exit 1
    fi

    # 2. テンプレートをクローン
    log_info "テンプレートをクローンしています..."
    git clone "$template_repo" "$project_name"
    cd "$project_name"

    # 3. Gitリモートを削除してクリーンアップ
    log_info "Gitリモートをクリーンアップしています..."
    git remote remove origin

    # 4. GitHubにプライベートリポジトリを作成
    log_info "GitHubにプライベートリポジトリを作成しています..."
    gh repo create "$project_name" --private --source=. --remote=origin --push

    # 5. サブモジュールを初期化
    log_info "AI指示書システム（サブモジュール）を初期化しています..."
    git submodule update --init --recursive

    # 6. プロジェクト設定を更新
    log_info "プロジェクト設定を更新しています..."

    # PROJECT.mdのリポジトリ名を更新
    if [ -f "instructions/PROJECT.md" ]; then
        # GitHubユーザー名を取得
        local github_user=$(gh api user --jq '.login')
        sed -i.bak "s|https://github.com/ユーザー名/リポジトリ名|https://github.com/${github_user}/${project_name}|g" instructions/PROJECT.md
        rm -f instructions/PROJECT.md.bak
    fi

    # READMEのリンクを更新
    if [ -f "README.md" ]; then
        local github_user=$(gh api user --jq '.login')
        sed -i.bak "s|あなたのユーザー名|${github_user}|g" README.md
        sed -i.bak "s|あなたのリポジトリ名|${project_name}|g" README.md
        sed -i.bak "s|ユーザー名/リポジトリ名|${github_user}/${project_name}|g" README.md
        rm -f README.md.bak
    fi

    # 7. 初期コミット（設定更新）
    log_info "設定更新をコミットしています..."
    git add .
    git commit -m "docs: プロジェクト設定を更新 (${project_name})"
    git push origin main

    # 8. セットアップスクリプトの実行確認
    log_info "依存関係のセットアップを実行しますか？"
    echo "  これにより以下がインストールされます："
    echo "  - Pandoc（必須）"
    echo "  - Quarto（オプション）"
    echo "  - 日本語LaTeX環境（オプション）"
    echo ""
    read -p "セットアップを実行しますか？ (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        log_info "セットアップスクリプトを実行しています..."
        make setup
    else
        log_info "セットアップをスキップしました。後で 'make setup' を実行できます"
    fi

    # 9. 完了メッセージ
    log_success "プロジェクト '${project_name}' の作成が完了しました！"
    echo ""
    echo "次のステップ:"
    echo "  cd ${project_name}"
    echo "  make help                    # 利用可能なコマンドを表示"
    echo "  cat instructions/PROJECT.md  # プロジェクト設定を確認"
    echo ""
    echo "報告書の作成:"
    echo "  make dev          # 開発モード（自動ビルド + 監視）"
    echo "  make build        # HTMLビルド"
    echo "  make build-pdf    # PDFビルド"
    echo "  make build-all    # HTML/PDF両方を生成"
    echo ""
    echo "GitHubリポジトリ:"
    local github_user=$(gh api user --jq '.login')
    echo "  https://github.com/${github_user}/${project_name}"
    echo ""
    echo "詳細なドキュメント:"
    echo "  README.md                                           # プロジェクト全体の説明"
    echo "  instructions/ai_instruction_kits/...ROOT_INSTRUCTION.md  # AI指示書システム"
}

# スクリプト実行
if [ $# -ne 1 ]; then
    usage
fi

check_prerequisites
main "$1"