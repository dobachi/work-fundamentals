# 調査報告書作成プロジェクト設定

このプロジェクトは調査報告書作成に特化したテンプレートリポジトリです。
AI指示書システムを活用して、信頼性の高い調査報告書を効率的に作成します。

## AI指示書システムの使用

タスク開始時は`instructions/ai_instruction_kits/instructions/ja/system/ROOT_INSTRUCTION.md`を読み込んでください。

## プロジェクト設定

- **目的**: 調査報告書の作成支援
- **対象分野**: IT技術、法制度、ソフトウェアプロジェクト等
- **言語**: 日本語（英語版も対応可）
- **出力形式**: HTML, PDF, Markdown
- **チェックポイント管理**: 有効
- **チェックポイントスクリプト**: scripts/checkpoint.sh
- **ログファイル**: checkpoint.log

## 重要なパス

- AI指示書システム: `instructions/ai_instruction_kits/`
- 報告書テンプレート: `reports/templates/`
- 調査資料: `sources/`
- 出力先: `output/`
- チェックポイントスクリプト: `scripts/checkpoint.sh`
- プロジェクト固有の設定: このファイル（`instructions/PROJECT.md`）

## 報告書作成の基本方針

### 必須要素

1. **エグゼクティブサマリ**
   - 1-2ページで全体を要約
   - 主要な発見事項と推奨事項を明記

2. **参考文献一覧**
   - すべての引用元を記載
   - 信頼性の高い情報源を優先

### 品質基準

1. **事実の記述**
   - 必ず引用元情報を示す
   - 参考文献との相互参照を確保

2. **多角的視点**
   - 複数の見解を調査・検討
   - バランスの取れた分析

3. **明確な区別**
   - 事実と考察を明確に区別
   - 推測や意見は明示的に表記

4. **信頼性の高い情報源**
   - 行政発表、学術論文、標準文書を優先
   - 一次情報源を重視

## コミットルール

- **必須**: `bash scripts/commit.sh "メッセージ"` または `git commit -m "メッセージ"`
- **禁止**: AI署名付きコミット（自動検出・拒否）

## ビルドコマンド

### 🚀 Quarto統合ビルドシステム（推奨）
```bash
# 📦 初回セットアップ
scripts/setup-quarto.sh                  # Quartoインストール＋プロジェクト設定

# 🔨 基本ビルド（従来の複数スクリプトを1つに統合）
scripts/build-quarto.sh                  # 全形式ビルド
scripts/build-quarto.sh --format html    # HTML形式のみ
scripts/build-quarto.sh --format pdf     # PDF形式のみ
scripts/build-quarto.sh --preview        # ライブプレビュー起動

# 🔄 統合開発環境（推奨）
scripts/dev-server.sh                     # プレビュー + 自動ビルド統合
scripts/dev-server.sh --port 4000         # カスタムポート
scripts/dev-server.sh --no-auto-build    # プレビューのみ

# 🔄 自動ビルド（単独）
scripts/auto-build-quarto.sh             # 自動ビルド開始
scripts/auto-build-quarto.sh --format html # HTML自動ビルド

# ⚡ 直接Quartoコマンド（最もシンプル）
quarto render                             # プロジェクト全体をビルド
quarto render reports/report.qmd          # 特定ファイルをビルド
quarto preview                            # ライブプレビュー開始
```

### 📋 参考文献チェック（引き続き利用可能）
```bash
# 引用整合性チェック（URL必須化・相互参照チェック含む）
scripts/check-references.sh reports/report.qmd

# URL有効性も含むチェック（推奨）
scripts/check-references.sh reports/report.qmd --check-urls
```

### 💡 Quartoの利点
- **簡素化**: 統合されたコマンドライン操作
- **自動化**: 相互参照、目次生成、引用管理が自動
- **美しさ**: プロフェッショナルなデフォルトテーマ
- **速度**: 高速なビルド処理

### 🤖 AIによる自動活用指示（Quarto版）
調査報告書作成タスクでは、以下の**Quartoワークフロー**を活用してください：

1. **🔧 初期設定**:
   - `scripts/setup-quarto.sh`でQuarto環境を構築
   - プロジェクト設定と依存関係を自動解決

2. **✏️ 執筆段階**:
   - `scripts/dev-server.sh`で統合開発環境を開始（推奨）
   - または個別に`quarto preview` + `scripts/auto-build-quarto.sh`
   - `.qmd`ファイルで執筆（自動相互参照・引用管理）

3. **🔍 品質管理**:
   - `scripts/check-references.sh`で引用の整合性確認
   - Quartoビルトイン機能で相互参照の自動検証

4. **📊 中間レビュー**: `quarto render --to html`で高品質プレビュー
5. **📋 最終出力**: `quarto render`で HTML/PDF同時生成
6. **🚀 CI/CD**: GitHub ActionsでQuarto自動ビルド・デプロイ

### 品質チェック自動化
- 引用番号の連続性確認
- 参考文献との対応チェック
- 未使用参考文献の検出
- リンク切れの自動検出

## プロジェクト固有の追加指示

### 調査時の留意事項

- 最新の情報を優先（公開日時を確認）
- 複数の情報源でクロスチェック
- 原文へのアクセス可能性を確保（URLや書誌情報）

### 執筆時の留意事項

- 専門用語は初出時に説明
- 図表には必ず説明文を付与
- 略語は初出時にフルスペルを記載

### Markdown記法の留意事項

- **強調表現の後は必ず空行を挿入**: `**太字**`や`*斜体*`の直後に箇条書きや段落を続ける場合は、間に空行を必ず入れる
- **箇条書きの前後**: 箇条書きの前後には空行を入れ、レンダリングの崩れを防ぐ
- **見出しとコンテンツの分離**: 見出し（`#`、`##`等）の後は空行を入れてから本文を開始する

#### 正しい例
```markdown
**重要なポイント**

- 項目1
- 項目2
- 項目3

次の段落が続きます。
```

#### 避けるべき例
```markdown
**重要なポイント**
- 項目1（レンダリングが崩れる可能性）
- 項目2
```

### レビュー時の留意事項

- 引用の正確性を確認
- 論理的一貫性をチェック
- 読者視点での分かりやすさを評価 