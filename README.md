# Work Fundamentals - 仕事の基礎ガイド

[English](README.en.md) | 日本語

## 📘 ガイドを読む

**[→ 仕事の基礎ガイドを読む](https://dobachi.github.io/work-fundamentals/)**

**ダウンロード**: [PDF](https://dobachi.github.io/work-fundamentals/reports/work-guide.pdf) | [Word](https://dobachi.github.io/work-fundamentals/reports/work-guide.docx)

---

## このガイドについて

**「何をすればいいか分からない」「何をどう報告すればいいか分からない」を解消し、自律的に動けるようになる**ための実践ガイドです。

## 対象読者

- 仕事の進め方に悩んでいる方
- 「指示がないと動けない」と感じている方
- 報告・相談の仕方に苦手意識がある方
- タスク管理や時間管理を改善したい方

**特に新人・若手社員の方に役立つ内容ですが、経験年数に関わらず仕事の基礎を見直したい方にもおすすめです。**

## このガイドが解決する課題

| 課題 | 解決策 |
|------|--------|
| 何をすればいいか分からない | タスク管理の基本ルール、優先順位の決め方 |
| 何をどう報告すればいいか分からない | 報告の基本構造、場面別の報告テンプレート |
| 一人で抱え込んでしまう | 30分ルール、相談の仕方 |
| 時間管理ができない | タイムボックス、タイムブロック |
| 会議でどう振る舞えばいいか分からない | 会議前・中・後のチェックリスト |

## ガイドの構成

### Part 1: 日常業務編
- 朝イチでやること（毎日のルーティン）
- タスク管理の基本ルール
- 報告の仕方（何を・どう報告するか）
- 時間を区切って作業する

### Part 2: プロジェクト遂行編
- プロジェクト参加時の心構え
- タスク遂行のフロー
- 会議の参加の仕方
- 成果物作成のポイント

### Part 3: 困ったときの対処法
- よくある困りごとと解決策
- 上司との1on1の活用

### 付録: チェックリスト
- 毎日のチェックリスト
- 週次のチェックリスト
- 月次のチェックリスト
- プロジェクト開始時のチェックリスト

---

## このガイドを開発・改善したい方へ

以下は、このガイド自体を開発・改善したい方（ドキュメント開発者）向けの情報です。

### リポジトリ情報

- **GitHub**: [dobachi/work-fundamentals](https://github.com/dobachi/work-fundamentals)
- **公開URL**: https://dobachi.github.io/work-fundamentals/
- **ライセンス**: Apache-2.0

### プロジェクト構造

```
work-fundamentals/
├── index.qmd                # トップページ
├── reports/                 # ガイド本文
│   └── work-guide.qmd       # メインガイド
├── sources/
│   └── diagrams/            # 図表（SVG形式）
├── instructions/            # AI支援用の指示書
├── output/                  # ビルド成果物（GitHub Pagesで公開）
└── README.md                # このファイル
```

### ローカルでビルドする場合

```bash
# リポジトリをクローン
git clone https://github.com/dobachi/work-fundamentals.git
cd work-fundamentals

# HTML・PDF・Wordをビルド
make build

# ライブプレビュー
make preview
```

#### 利用可能なコマンド

| コマンド | 説明 |
|----------|------|
| `make build` | ガイドをHTML・PDF・Word形式でビルド |
| `make html` | ガイドをHTML形式のみでビルド |
| `make pdf` | ガイドをPDF形式のみでビルド |
| `make docx` | ガイドをWord形式のみでビルド |
| `make preview` | ブラウザでライブプレビュー起動 |
| `make clean` | ビルド成果物を削除 |

### AI支援

このリポジトリはAIアシスタント（Claude、Cursor、Geminiなど）と連携できます。
`instructions/PROJECT.md` にAI向けの指示が記載されています。

### デプロイ

mainブランチへのpush時に自動的にGitHub Pagesへビルド・デプロイされます。

## 作者

Dobachi
