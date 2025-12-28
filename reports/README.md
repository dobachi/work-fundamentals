# ユーザー報告書ディレクトリ

このディレクトリには、あなたが作成する調査報告書を配置します。

## 使い方

### 1. テンプレートから報告書を作成

```bash
# テンプレートをコピー
cp templates/report_template.qmd reports/my-research.qmd

# エディタで編集
vim reports/my-research.qmd
```

### 2. 報告書をビルド

```bash
# HTML + PDF形式でビルド
make report

# 成果物は output/ に生成されます
ls output/my-research.*
```

### 3. 配布用パッケージを作成

```bash
# 成果物 + ソースをZIPでパッケージ化
make package

# dist/ に生成されます
ls dist/
```

## ファイル構成の推奨

### 単一の報告書の場合

```
reports/
└── my-research.qmd
```

### 複数の報告書の場合

```
reports/
├── 2025-project-a.qmd
├── 2025-project-b.qmd
└── 2025-survey-results.qmd
```

## 参考

- [テンプレート一覧](../templates/README.md)
- [サンプル報告書](../examples/)
- [プロジェクトREADME](../README.md)

## 注意事項

- このディレクトリ内の`.qmd`ファイルはgit管理されません（`.gitignore`で除外）
- ビルド成果物（`.html`, `.pdf`等）も自動的に無視されます
- 報告書を共有したい場合は、`make package`で配布用パッケージを作成してください
