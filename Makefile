# 調査報告書ビルドシステム Makefile
# 設計原則：
# 1. templates/ = テンプレートファイル（ビルド対象外、コピー元）
# 2. reports/ = ユーザーの報告書（ビルド対象）
# 3. examples/ = サンプル報告書（ビルド対象、GitHub Pages表示）
# 4. output/ = ビルド成果物
# 5. dist/ = 配布用パッケージ

# 設定
OUTPUT_DIR := output
DIST_DIR := dist
PACKAGE_NAME := research-report-$(shell date +%Y%m%d)

# デフォルトターゲット
.PHONY: all
all: examples

# ヘルプ表示
.PHONY: help
help:
	@echo "利用可能なコマンド:"
	@echo ""
	@echo "【報告書作成】"
	@echo "  make report          - reports/内のユーザー報告書をビルド（HTML + PDF）"
	@echo "  make report-html     - reports/内のユーザー報告書をHTMLでビルド"
	@echo "  make report-pdf      - reports/内のユーザー報告書をPDFでビルド"
	@echo ""
	@echo "【サンプル・デモ】"
	@echo "  make examples        - examples/内のサンプル報告書をビルド（HTML + PDF）"
	@echo "  make examples-html   - examples/内のサンプル報告書をHTMLでビルド"
	@echo "  make examples-pdf    - examples/内のサンプル報告書をPDFでビルド"
	@echo ""
	@echo "【配布】"
	@echo "  make package         - 報告書を配布用パッケージ化（成果物 + ソース）"
	@echo ""
	@echo "【開発・プレビュー】"
	@echo "  make preview         - ライブプレビュー起動"
	@echo "  make clean           - ビルド成果物を削除"
	@echo ""
	@echo "【使い方】"
	@echo "  1. cp templates/report_template.qmd reports/my-research.qmd"
	@echo "  2. vim reports/my-research.qmd  # 報告書を編集"
	@echo "  3. make report                  # ビルド"
	@echo "  4. make package                 # 配布用ZIP作成"

# ===============================================
# ユーザー報告書のビルド
# ===============================================

.PHONY: report
report: report-html report-pdf
	@echo "✅ 報告書ビルド完了"
	@echo "📍 成果物: $(OUTPUT_DIR)/"
	@find $(OUTPUT_DIR) -maxdepth 1 \( -name "*.html" -o -name "*.pdf" \) -exec ls -lh {} \; 2>/dev/null || echo "  （ファイルなし）"

.PHONY: report-html
report-html:
	@echo "📄 reports/内の報告書をHTMLでビルド中..."
	@if [ -z "$$(find reports -name '*.qmd' -not -name 'README.md' 2>/dev/null)" ]; then \
		echo "⚠️  reports/内に.qmdファイルがありません"; \
		echo "   cp templates/report_template.qmd reports/my-research.qmd"; \
		exit 0; \
	fi
	@quarto render reports/ --to html --output-dir $(OUTPUT_DIR)
	@echo "✅ HTML生成完了"
	@echo "📍 HTML出力先: $(OUTPUT_DIR)/"

.PHONY: report-pdf
report-pdf:
	@echo "📋 reports/内の報告書をPDFでビルド中..."
	@if [ -z "$$(find reports -name '*.qmd' -not -name 'README.md' 2>/dev/null)" ]; then \
		echo "⚠️  reports/内に.qmdファイルがありません"; \
		exit 0; \
	fi
	@quarto render reports/ --to pdf --output-dir $(OUTPUT_DIR)
	@echo "✅ PDF生成完了"
	@echo "📍 PDF出力先: $(OUTPUT_DIR)/"

# ===============================================
# サンプル報告書のビルド（GitHub Pages表示用）
# ===============================================

.PHONY: examples
examples: examples-html examples-pdf
	@echo "✅ サンプルビルド完了"
	@echo "📍 成果物: $(OUTPUT_DIR)/examples/"
	@find $(OUTPUT_DIR)/examples -name "*.html" -o -name "*.pdf" 2>/dev/null | xargs ls -lh 2>/dev/null || echo "  （ファイルなし）"

.PHONY: examples-html
examples-html:
	@echo "📚 examples/内のサンプル報告書をHTMLでビルド中..."
	@mkdir -p $(OUTPUT_DIR)
	@quarto render examples/ --to html --output-dir $(OUTPUT_DIR)
	@echo "✅ サンプルHTML生成完了"
	@echo "📍 HTML出力先: $(OUTPUT_DIR)/examples/"
	@ls -lh $(OUTPUT_DIR)/examples/*.html 2>/dev/null || echo "  （HTMLファイルなし）"

.PHONY: examples-pdf
examples-pdf:
	@echo "📋 examples/内のサンプル報告書をPDFでビルド中..."
	@mkdir -p $(OUTPUT_DIR)
	@quarto render examples/ --to pdf --output-dir $(OUTPUT_DIR)
	@echo "✅ サンプルPDF生成完了"
	@echo "📍 PDF出力先: $(OUTPUT_DIR)/examples/"
	@ls -lh $(OUTPUT_DIR)/examples/*.pdf 2>/dev/null || echo "  （PDFファイルなし）"

# ===============================================
# 配布用パッケージ作成
# ===============================================

.PHONY: package
package:
	@echo "📦 Quartoビルド可能な配布パッケージ作成中..."
	@
	@# ディレクトリ構造を作成
	@mkdir -p $(DIST_DIR)/package/templates/styles
	@mkdir -p $(DIST_DIR)/package/sources/references
	@mkdir -p $(DIST_DIR)/package/sources/diagrams
	@mkdir -p $(DIST_DIR)/package/reports
	@mkdir -p $(DIST_DIR)/package/scripts
	@
	@# Quarto設定ファイルを生成（パッケージ用に調整）
	@echo "  - Quarto設定ファイルを生成中..."
	@echo "project:" > $(DIST_DIR)/package/_quarto.yml
	@echo "  output-dir: output" >> $(DIST_DIR)/package/_quarto.yml
	@echo "" >> $(DIST_DIR)/package/_quarto.yml
	@echo "format:" >> $(DIST_DIR)/package/_quarto.yml
	@echo "  html:" >> $(DIST_DIR)/package/_quarto.yml
	@echo "    theme:" >> $(DIST_DIR)/package/_quarto.yml
	@echo "      - journal" >> $(DIST_DIR)/package/_quarto.yml
	@echo "      - templates/styles/custom.scss" >> $(DIST_DIR)/package/_quarto.yml
	@echo "    toc: true" >> $(DIST_DIR)/package/_quarto.yml
	@echo "    toc-depth: 3" >> $(DIST_DIR)/package/_quarto.yml
	@echo "    number-sections: true" >> $(DIST_DIR)/package/_quarto.yml
	@echo "    code-fold: true" >> $(DIST_DIR)/package/_quarto.yml
	@echo "    css: templates/styles/report-style.css" >> $(DIST_DIR)/package/_quarto.yml
	@echo "    link-external-newwindow: true" >> $(DIST_DIR)/package/_quarto.yml
	@echo "" >> $(DIST_DIR)/package/_quarto.yml
	@echo "  pdf:" >> $(DIST_DIR)/package/_quarto.yml
	@echo "    documentclass: ltjsbook" >> $(DIST_DIR)/package/_quarto.yml
	@echo "    toc: true" >> $(DIST_DIR)/package/_quarto.yml
	@echo "    number-sections: true" >> $(DIST_DIR)/package/_quarto.yml
	@echo "    geometry: margin=2cm" >> $(DIST_DIR)/package/_quarto.yml
	@echo "    pdf-engine: lualatex" >> $(DIST_DIR)/package/_quarto.yml
	@echo "    include-in-header:" >> $(DIST_DIR)/package/_quarto.yml
	@echo "      - text: |" >> $(DIST_DIR)/package/_quarto.yml
	@echo "          \\usepackage{luatexja-fontspec}" >> $(DIST_DIR)/package/_quarto.yml
	@echo "          \\setmainjfont{Noto Sans CJK JP}" >> $(DIST_DIR)/package/_quarto.yml
	@echo "" >> $(DIST_DIR)/package/_quarto.yml
	@echo "  docx:" >> $(DIST_DIR)/package/_quarto.yml
	@echo "    toc: true" >> $(DIST_DIR)/package/_quarto.yml
	@echo "    number-sections: true" >> $(DIST_DIR)/package/_quarto.yml
	@echo "    highlight-style: github" >> $(DIST_DIR)/package/_quarto.yml
	@echo "" >> $(DIST_DIR)/package/_quarto.yml
	@echo "bibliography: sources/references/bibliography.bib" >> $(DIST_DIR)/package/_quarto.yml
	@echo "" >> $(DIST_DIR)/package/_quarto.yml
	@echo "crossref:" >> $(DIST_DIR)/package/_quarto.yml
	@echo "  fig-title: \"図\"" >> $(DIST_DIR)/package/_quarto.yml
	@echo "  tbl-title: \"表\"" >> $(DIST_DIR)/package/_quarto.yml
	@echo "  title-delim: \":\"" >> $(DIST_DIR)/package/_quarto.yml
	@echo "  fig-prefix: \"図\"" >> $(DIST_DIR)/package/_quarto.yml
	@echo "  tbl-prefix: \"表\"" >> $(DIST_DIR)/package/_quarto.yml
	@
	@# テンプレートとスタイルをコピー
	@echo "  - テンプレートとスタイルをコピー中..."
	@cp templates/report_template.qmd $(DIST_DIR)/package/templates/ 2>/dev/null || true
	@cp -r templates/styles/* $(DIST_DIR)/package/templates/styles/ 2>/dev/null || true
	@
	@# 参考文献をコピー
	@echo "  - 参考文献をコピー中..."
	@cp sources/references/*.bib $(DIST_DIR)/package/sources/references/ 2>/dev/null || true
	@
	@# 図表ソースをコピー
	@echo "  - 図表ソースをコピー中..."
	@cp -r sources/diagrams/* $(DIST_DIR)/package/sources/diagrams/ 2>/dev/null || true
	@
	@# 報告書ソースをコピー（reports/ または examples/）
	@echo "  - 報告書ソースをコピー中..."
	@if [ -n "$$(find reports -name '*.qmd' -not -name 'README.md' 2>/dev/null)" ]; then \
		find reports -name '*.qmd' -not -name 'README.md' -exec cp {} $(DIST_DIR)/package/reports/ \; 2>/dev/null || true; \
		echo "    reports/からコピーしました"; \
	else \
		find examples -name '*.qmd' -exec cp {} $(DIST_DIR)/package/reports/ \; 2>/dev/null || true; \
		echo "    examples/からコピーしました（サンプル）"; \
	fi
	@
	@# ビルドスクリプトをコピー
	@echo "  - ビルドスクリプトをコピー中..."
	@cp scripts/build-quarto.sh $(DIST_DIR)/package/scripts/ 2>/dev/null || true
	@cp scripts/setup-quarto.sh $(DIST_DIR)/package/scripts/ 2>/dev/null || true
	@chmod +x $(DIST_DIR)/package/scripts/*.sh 2>/dev/null || true
	@
	@# Makefileをコピー（簡易版）
	@echo "  - Makefileをコピー中..."
	@cp Makefile $(DIST_DIR)/package/
	@
	@# READMEを生成
	@echo "  - READMEを生成中..."
	@echo "# 調査報告書パッケージ（Quarto版）" > $(DIST_DIR)/package/README.md
	@echo "" >> $(DIST_DIR)/package/README.md
	@echo "このパッケージはQuartoでビルド可能な調査報告書のソースと設定ファイル一式です。" >> $(DIST_DIR)/package/README.md
	@echo "" >> $(DIST_DIR)/package/README.md
	@echo "生成日時: $$(date '+%Y-%m-%d %H:%M:%S')" >> $(DIST_DIR)/package/README.md
	@echo "" >> $(DIST_DIR)/package/README.md
	@echo "## 📁 ディレクトリ構造" >> $(DIST_DIR)/package/README.md
	@echo "" >> $(DIST_DIR)/package/README.md
	@echo "\`\`\`" >> $(DIST_DIR)/package/README.md
	@echo "." >> $(DIST_DIR)/package/README.md
	@echo "├── README.md              # このファイル" >> $(DIST_DIR)/package/README.md
	@echo "├── _quarto.yml            # Quarto設定ファイル" >> $(DIST_DIR)/package/README.md
	@echo "├── Makefile               # ビルドコマンド" >> $(DIST_DIR)/package/README.md
	@echo "├── templates/             # テンプレート" >> $(DIST_DIR)/package/README.md
	@echo "│   ├── report_template.qmd # 報告書テンプレート" >> $(DIST_DIR)/package/README.md
	@echo "│   └── styles/            # スタイルファイル" >> $(DIST_DIR)/package/README.md
	@echo "├── sources/               # 資料" >> $(DIST_DIR)/package/README.md
	@echo "│   ├── references/        # 参考文献（.bib）" >> $(DIST_DIR)/package/README.md
	@echo "│   └── diagrams/          # 図表ソース" >> $(DIST_DIR)/package/README.md
	@echo "├── reports/               # 報告書ソース（.qmd）" >> $(DIST_DIR)/package/README.md
	@echo "└── scripts/               # ビルドスクリプト" >> $(DIST_DIR)/package/README.md
	@echo "\`\`\`" >> $(DIST_DIR)/package/README.md
	@echo "" >> $(DIST_DIR)/package/README.md
	@echo "## 🚀 クイックスタート" >> $(DIST_DIR)/package/README.md
	@echo "" >> $(DIST_DIR)/package/README.md
	@echo "### 1. 環境セットアップ" >> $(DIST_DIR)/package/README.md
	@echo "" >> $(DIST_DIR)/package/README.md
	@echo "セットアップスクリプトを使用（推奨）：" >> $(DIST_DIR)/package/README.md
	@echo "" >> $(DIST_DIR)/package/README.md
	@echo "\`\`\`bash" >> $(DIST_DIR)/package/README.md
	@echo "bash scripts/setup-quarto.sh" >> $(DIST_DIR)/package/README.md
	@echo "\`\`\`" >> $(DIST_DIR)/package/README.md
	@echo "" >> $(DIST_DIR)/package/README.md
	@echo "手動セットアップ：" >> $(DIST_DIR)/package/README.md
	@echo "" >> $(DIST_DIR)/package/README.md
	@echo "**Quartoのインストール**" >> $(DIST_DIR)/package/README.md
	@echo "" >> $(DIST_DIR)/package/README.md
	@echo "- Ubuntu/Debian: \`sudo apt install quarto\`" >> $(DIST_DIR)/package/README.md
	@echo "- macOS: \`brew install quarto\`" >> $(DIST_DIR)/package/README.md
	@echo "- その他: https://quarto.org/docs/get-started/" >> $(DIST_DIR)/package/README.md
	@echo "" >> $(DIST_DIR)/package/README.md
	@echo "**日本語PDF生成のための追加パッケージ**" >> $(DIST_DIR)/package/README.md
	@echo "" >> $(DIST_DIR)/package/README.md
	@echo "- Ubuntu/Debian:" >> $(DIST_DIR)/package/README.md
	@echo "  \`\`\`bash" >> $(DIST_DIR)/package/README.md
	@echo "  sudo apt install texlive-xetex fonts-noto-cjk" >> $(DIST_DIR)/package/README.md
	@echo "  \`\`\`" >> $(DIST_DIR)/package/README.md
	@echo "" >> $(DIST_DIR)/package/README.md
	@echo "- macOS:" >> $(DIST_DIR)/package/README.md
	@echo "  \`\`\`bash" >> $(DIST_DIR)/package/README.md
	@echo "  brew install --cask mactex" >> $(DIST_DIR)/package/README.md
	@echo "  brew install font-noto-sans-cjk-jp" >> $(DIST_DIR)/package/README.md
	@echo "  \`\`\`" >> $(DIST_DIR)/package/README.md
	@echo "" >> $(DIST_DIR)/package/README.md
	@echo "### 2. ビルド実行" >> $(DIST_DIR)/package/README.md
	@echo "" >> $(DIST_DIR)/package/README.md
	@echo "**Makeを使用（簡単）：**" >> $(DIST_DIR)/package/README.md
	@echo "" >> $(DIST_DIR)/package/README.md
	@echo "\`\`\`bash" >> $(DIST_DIR)/package/README.md
	@echo "make report          # HTML + PDF" >> $(DIST_DIR)/package/README.md
	@echo "make report-html     # HTMLのみ" >> $(DIST_DIR)/package/README.md
	@echo "make report-pdf      # PDFのみ" >> $(DIST_DIR)/package/README.md
	@echo "\`\`\`" >> $(DIST_DIR)/package/README.md
	@echo "" >> $(DIST_DIR)/package/README.md
	@echo "**Quartoコマンド直接実行：**" >> $(DIST_DIR)/package/README.md
	@echo "" >> $(DIST_DIR)/package/README.md
	@echo "\`\`\`bash" >> $(DIST_DIR)/package/README.md
	@echo "# HTML生成" >> $(DIST_DIR)/package/README.md
	@echo "quarto render reports/ --to html --output-dir output" >> $(DIST_DIR)/package/README.md
	@echo "" >> $(DIST_DIR)/package/README.md
	@echo "# PDF生成" >> $(DIST_DIR)/package/README.md
	@echo "quarto render reports/ --to pdf --output-dir output" >> $(DIST_DIR)/package/README.md
	@echo "" >> $(DIST_DIR)/package/README.md
	@echo "# DOCX生成" >> $(DIST_DIR)/package/README.md
	@echo "quarto render reports/ --to docx --output-dir output" >> $(DIST_DIR)/package/README.md
	@echo "\`\`\`" >> $(DIST_DIR)/package/README.md
	@echo "" >> $(DIST_DIR)/package/README.md
	@echo "**ビルドスクリプト使用：**" >> $(DIST_DIR)/package/README.md
	@echo "" >> $(DIST_DIR)/package/README.md
	@echo "\`\`\`bash" >> $(DIST_DIR)/package/README.md
	@echo "bash scripts/build-quarto.sh                # 全形式" >> $(DIST_DIR)/package/README.md
	@echo "bash scripts/build-quarto.sh --format html  # HTML" >> $(DIST_DIR)/package/README.md
	@echo "bash scripts/build-quarto.sh --format pdf   # PDF" >> $(DIST_DIR)/package/README.md
	@echo "\`\`\`" >> $(DIST_DIR)/package/README.md
	@echo "" >> $(DIST_DIR)/package/README.md
	@echo "### 3. プレビュー" >> $(DIST_DIR)/package/README.md
	@echo "" >> $(DIST_DIR)/package/README.md
	@echo "リアルタイムプレビュー：" >> $(DIST_DIR)/package/README.md
	@echo "" >> $(DIST_DIR)/package/README.md
	@echo "\`\`\`bash" >> $(DIST_DIR)/package/README.md
	@echo "quarto preview reports/" >> $(DIST_DIR)/package/README.md
	@echo "# または" >> $(DIST_DIR)/package/README.md
	@echo "make preview" >> $(DIST_DIR)/package/README.md
	@echo "\`\`\`" >> $(DIST_DIR)/package/README.md
	@echo "" >> $(DIST_DIR)/package/README.md
	@echo "## 📝 報告書の作成・編集" >> $(DIST_DIR)/package/README.md
	@echo "" >> $(DIST_DIR)/package/README.md
	@echo "1. テンプレートをコピー：" >> $(DIST_DIR)/package/README.md
	@echo "   \`\`\`bash" >> $(DIST_DIR)/package/README.md
	@echo "   cp templates/report_template.qmd reports/my-report.qmd" >> $(DIST_DIR)/package/README.md
	@echo "   \`\`\`" >> $(DIST_DIR)/package/README.md
	@echo "" >> $(DIST_DIR)/package/README.md
	@echo "2. エディタで編集：" >> $(DIST_DIR)/package/README.md
	@echo "   \`\`\`bash" >> $(DIST_DIR)/package/README.md
	@echo "   vim reports/my-report.qmd" >> $(DIST_DIR)/package/README.md
	@echo "   \`\`\`" >> $(DIST_DIR)/package/README.md
	@echo "" >> $(DIST_DIR)/package/README.md
	@echo "3. ビルド：" >> $(DIST_DIR)/package/README.md
	@echo "   \`\`\`bash" >> $(DIST_DIR)/package/README.md
	@echo "   make report" >> $(DIST_DIR)/package/README.md
	@echo "   \`\`\`" >> $(DIST_DIR)/package/README.md
	@echo "" >> $(DIST_DIR)/package/README.md
	@echo "## 🔧 カスタマイズ" >> $(DIST_DIR)/package/README.md
	@echo "" >> $(DIST_DIR)/package/README.md
	@echo "### スタイルのカスタマイズ" >> $(DIST_DIR)/package/README.md
	@echo "" >> $(DIST_DIR)/package/README.md
	@echo "- \`templates/styles/custom.scss\`: 全体のテーマ" >> $(DIST_DIR)/package/README.md
	@echo "- \`templates/styles/report-style.css\`: レポート固有のスタイル" >> $(DIST_DIR)/package/README.md
	@echo "" >> $(DIST_DIR)/package/README.md
	@echo "### Quarto設定の変更" >> $(DIST_DIR)/package/README.md
	@echo "" >> $(DIST_DIR)/package/README.md
	@echo "\`_quarto.yml\`を編集して以下を調整可能：" >> $(DIST_DIR)/package/README.md
	@echo "" >> $(DIST_DIR)/package/README.md
	@echo "- 出力形式（HTML、PDF、DOCX等）" >> $(DIST_DIR)/package/README.md
	@echo "- 目次の表示設定" >> $(DIST_DIR)/package/README.md
	@echo "- 番号付けの設定" >> $(DIST_DIR)/package/README.md
	@echo "- フォント設定（PDF）" >> $(DIST_DIR)/package/README.md
	@echo "" >> $(DIST_DIR)/package/README.md
	@echo "## 📚 参考資料" >> $(DIST_DIR)/package/README.md
	@echo "" >> $(DIST_DIR)/package/README.md
	@echo "- [Quarto公式ドキュメント](https://quarto.org)" >> $(DIST_DIR)/package/README.md
	@echo "- [Quarto日本語ガイド](https://quarto.org/docs/guides/)" >> $(DIST_DIR)/package/README.md
	@echo "- [ResearchTemplate GitHub](https://github.com/dobachi/ResearchTemplate)" >> $(DIST_DIR)/package/README.md
	@echo "" >> $(DIST_DIR)/package/README.md
	@echo "## ⚠️ 注意事項" >> $(DIST_DIR)/package/README.md
	@echo "" >> $(DIST_DIR)/package/README.md
	@echo "- このパッケージはQuartoビルド専用です" >> $(DIST_DIR)/package/README.md
	@echo "- AI指示書システムは含まれていません" >> $(DIST_DIR)/package/README.md
	@echo "- 完全な機能が必要な場合は元のリポジトリを参照してください" >> $(DIST_DIR)/package/README.md
	@
	@# ZIP圧縮
	@echo "  - アーカイブを作成中..."
	@cd $(DIST_DIR) && zip -r $(PACKAGE_NAME).zip package/ > /dev/null
	@rm -rf $(DIST_DIR)/package
	@
	@echo "✅ パッケージ生成完了: $(DIST_DIR)/$(PACKAGE_NAME).zip"
	@echo "📊 パッケージ情報:"
	@ls -lh $(DIST_DIR)/$(PACKAGE_NAME).zip
	@unzip -l $(DIST_DIR)/$(PACKAGE_NAME).zip | head -20

# ===============================================
# プレビュー・開発
# ===============================================

.PHONY: preview
preview:
	@echo "🔄 ライブプレビューを開始..."
	@echo "   reports/内の.qmdファイルを編集すると自動的に再ビルドされます"
	@quarto preview reports/

# ===============================================
# クリーンアップ
# ===============================================

.PHONY: clean
clean:
	@echo "🧹 ビルド成果物を削除中..."
	@rm -rf $(OUTPUT_DIR)/
	@rm -rf $(DIST_DIR)/
	@rm -rf .quarto/
	@rm -rf reports/*.html reports/*.pdf reports/*.epub reports/*_files/
	@rm -rf examples/*.html examples/*.pdf examples/*.epub examples/*_files/
	@echo "✅ クリーンアップ完了"

# ===============================================
# ディレクトリ作成
# ===============================================

$(OUTPUT_DIR):
	@mkdir -p $(OUTPUT_DIR)

$(DIST_DIR):
	@mkdir -p $(DIST_DIR)
