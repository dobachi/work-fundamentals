#!/usr/bin/env python3
"""
Quarto post-render スクリプト: DOCX内のテーブルラッパーを解除

Quartoは画像や表（特にキャプション付き）を1セルのテーブル内にラップして出力する。
このスクリプトは生成されたDOCXファイルを後処理し、
1セルテーブルから内容を抽出して通常の要素に変換する。

使用方法:
  _quarto.yml に以下を追加:
    project:
      post-render: scripts/fix-docx-figures.py
"""

import glob
import os
import sys
from pathlib import Path
from copy import deepcopy

try:
    from docx import Document
    from docx.oxml.ns import qn
    from docx.oxml import OxmlElement
    from docx.shared import Inches, Pt
except ImportError:
    print("警告: python-docx がインストールされていません。")
    print("インストール: pip install python-docx")
    sys.exit(0)  # エラーにせず終了（他の出力形式に影響しないように）


def is_wrapper_table(table):
    """1セルのラッパーテーブルかチェック（画像または表を含む）"""
    try:
        # 1行のテーブルかチェック
        if len(table.rows) != 1:
            return False, None

        row = table.rows[0]
        # 1セルかチェック
        if len(row.cells) != 1:
            return False, None

        cell = row.cells[0]

        # ネストされたテーブルを含むかチェック
        nested_tables = cell._element.findall('.//' + qn('w:tbl'))
        if nested_tables:
            return True, 'table'

        # 画像（drawing要素）を含むかチェック
        drawings = cell._element.findall('.//' + qn('w:drawing'))
        if drawings:
            return True, 'image'

        # インライン画像もチェック
        pics = cell._element.findall('.//' + qn('w:pict'))
        if pics:
            return True, 'image'

        return False, None
    except Exception:
        return False, None


def unwrap_tables(docx_path):
    """1セルラッパーテーブルを解除"""
    try:
        doc = Document(docx_path)
        modified = False

        # 複数回処理（ネストが深い場合に対応）
        max_iterations = 5
        for iteration in range(max_iterations):
            tables_to_process = []

            for table in doc.tables:
                is_wrapper, content_type = is_wrapper_table(table)
                if is_wrapper:
                    tables_to_process.append((table, content_type))

            if not tables_to_process:
                break  # 処理対象がなくなったら終了

            for table, content_type in tables_to_process:
                try:
                    tbl_element = table._tbl
                    parent = tbl_element.getparent()

                    if parent is None:
                        continue

                    # テーブルの位置を取得
                    tbl_index = list(parent).index(tbl_element)

                    # セルから内容を抽出
                    cell = table.rows[0].cells[0]

                    # セル内の全要素を収集
                    elements_to_insert = []

                    for child in list(cell._element):
                        tag = child.tag.split('}')[-1] if '}' in child.tag else child.tag

                        if tag == 'tbl':
                            # ネストされたテーブル
                            elements_to_insert.append(deepcopy(child))
                        elif tag == 'p':
                            # 段落（画像やキャプションを含む可能性）
                            elements_to_insert.append(deepcopy(child))
                        elif tag == 'tcPr':
                            # セルプロパティは無視
                            pass
                        else:
                            # その他の要素もコピー
                            elements_to_insert.append(deepcopy(child))

                    # 要素を挿入（逆順で挿入してインデックスを維持）
                    for i, elem in enumerate(elements_to_insert):
                        parent.insert(tbl_index + 1 + i, elem)

                    # ラッパーテーブルを削除
                    parent.remove(tbl_element)
                    modified = True

                except Exception as e:
                    print(f"  警告: テーブル処理中にエラー: {e}")
                    continue

        if modified:
            doc.save(docx_path)
            return True
        return False

    except Exception as e:
        print(f"  エラー: {docx_path} の処理に失敗: {e}")
        return False


def main():
    """メイン処理"""
    # Quartoの出力ディレクトリを特定
    output_dir = os.environ.get('QUARTO_PROJECT_OUTPUT_DIR', 'output')

    # カレントディレクトリからの相対パスで検索
    search_patterns = [
        f"{output_dir}/**/*.docx",
        "**/*.docx"
    ]

    docx_files = set()
    for pattern in search_patterns:
        for f in glob.glob(pattern, recursive=True):
            # 一時ファイルやバックアップを除外
            if not os.path.basename(f).startswith('~') and not f.endswith('.tmp'):
                docx_files.add(f)

    if not docx_files:
        print("処理対象のDOCXファイルが見つかりません。")
        return

    print(f"DOCXファイルのテーブルラッパー解除処理を開始...")

    processed = 0
    for docx_path in sorted(docx_files):
        print(f"  処理中: {docx_path}")
        if unwrap_tables(docx_path):
            print(f"    -> 修正完了")
            processed += 1
        else:
            print(f"    -> 変更なし")

    print(f"完了: {processed}/{len(docx_files)} ファイルを修正")


if __name__ == "__main__":
    main()
