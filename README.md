# Work Fundamentals - 仕事の基礎ガイド

[English](README.en.md) | 日本語

## ガイドを読む

**[仕事の基礎ガイドを読む](https://dobachi.github.io/work-fundamentals/)**

ダウンロード: [PDF](https://dobachi.github.io/work-fundamentals/reports/work-guide.pdf) | [Word](https://dobachi.github.io/work-fundamentals/reports/work-guide.docx)

---

## このガイドについて

「何をすればいいか分からない」「報告の仕方が分からない」を解消するための実践ガイドです。

## 対象読者

- 仕事の進め方に悩んでいる人
- 「指示がないと動けない」と感じている人
- 報告・相談の仕方に苦手意識がある人
- タスク管理や時間管理を改善したい人

新人・若手社員向けに書いていますが、経験年数に関わらず仕事の基礎を見直したい人にも使えます。

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
- 小さなチームやタスクのリーダーになったら

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

以下は、このガイド自体を開発・改善したい人向けの情報です。

### リポジトリ情報

- GitHub: [dobachi/work-fundamentals](https://github.com/dobachi/work-fundamentals)
- 公開URL: https://dobachi.github.io/work-fundamentals/
- ライセンス: Apache-2.0

### プロジェクト構造

```
work-fundamentals/
├── index.qmd                # トップページ
├── reports/                 # ガイド本文
│   └── work-guide.qmd
├── sources/
│   └── diagrams/            # 図表
├── instructions/            # AI支援用の指示書
├── output/                  # ビルド成果物
└── README.md
```

### ローカルでビルドする場合

```bash
# リポジトリをクローン
git clone https://github.com/dobachi/work-fundamentals.git
cd work-fundamentals

# ビルド
make build

# プレビュー
make preview
```

#### Makeコマンド

| コマンド | 説明 |
|----------|------|
| `make build` | HTML・PDF・Wordをビルド |
| `make html` | HTMLのみ |
| `make pdf` | PDFのみ |
| `make docx` | Wordのみ |
| `make preview` | ライブプレビュー |
| `make clean` | ビルド成果物を削除 |

### AI支援

このリポジトリはAIアシスタント（Claude、Cursor、Geminiなど）と連携できます。`instructions/PROJECT.md` にAI向けの指示が記載されています。

### デプロイ

mainブランチへのpush時に自動的にGitHub Pagesへビルド・デプロイされます。

## 作者

Dobachi
