# 調査報告書テンプレート

このディレクトリには、調査報告書作成用のテンプレートファイルが含まれています。

## 使い方

1. **テンプレートをコピー**
   ```bash
   cp templates/report_template.qmd reports/my-research.qmd
   ```

2. **報告書を編集**
   - `reports/my-research.qmd`をエディタで開く
   - タイトル、著者、内容を記入

3. **ビルド**
   ```bash
   make report
   ```

4. **成果物を確認**
   - `output/my-research.html` - HTML版
   - `output/my-research.pdf` - PDF版

## テンプレート一覧

### report_template.qmd
調査報告書の基本テンプレート。以下が含まれます：

- エグゼクティブサマリ
- 調査背景・目的
- 調査方法
- 調査結果
- 考察
- 結論
- 参考文献

### スタイル

- `styles/` - カスタムCSSとSCSSファイル
  - `report-style.css` - 基本スタイル
  - `custom.scss` - カスタマイズ用

## カスタマイズ

テンプレートのメタデータ（YAMLフロントマター）をプロジェクトに合わせて編集してください：

```yaml
title: "調査報告書タイトル"
subtitle: "サブタイトル（必要に応じて）"
author:
  - name: 主執筆者名
    affiliation: 所属組織
    email: email@example.com
date: today
```

## 参考

- [Quarto公式ドキュメント](https://quarto.org/docs/guide/)
- [プロジェクトREADME](../README.md)
