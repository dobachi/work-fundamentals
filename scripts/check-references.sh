#!/bin/bash

# 参考文献チェックスクリプト
# 報告書内の引用と参考文献の整合性をチェック

set -e

# カラー出力
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 使用法
show_usage() {
    cat << EOF
使用法: $0 report.md

報告書内の引用と参考文献の整合性をチェックします。

チェック項目:
  - 引用番号の連続性
  - 参考文献リストとの対応
  - 未使用の参考文献
  - 参考文献のURL必須チェック
  - 相互参照の充実度
  - URLの有効性（オプション）

例:
  $0 reports/my-report.md
  $0 reports/my-report.md --check-urls

EOF
}

# 引数チェック
if [ $# -lt 1 ]; then
    show_usage
    exit 1
fi

REPORT_FILE=$1
CHECK_URLS=${2:-""}

if [ ! -f "$REPORT_FILE" ]; then
    echo -e "${RED}エラー: ファイル '$REPORT_FILE' が見つかりません${NC}"
    exit 1
fi

echo -e "${BLUE}=== 参考文献チェック ===${NC}"
echo "対象ファイル: $REPORT_FILE"
echo ""

# 統計情報の初期化
TOTAL_CITATIONS=0
TOTAL_REFERENCES=0
MISSING_CITATIONS=()
UNUSED_REFERENCES=()
BROKEN_URLS=()

# 引用の抽出 [^番号]
echo -e "${GREEN}引用をチェック中...${NC}"
CITATIONS=$(grep -o '\[\^[0-9]\+\]' "$REPORT_FILE" | sed 's/\[\^\([0-9]\+\)\]/\1/' | sort -nu)

if [ -n "$CITATIONS" ]; then
    TOTAL_CITATIONS=$(echo "$CITATIONS" | wc -l)
    echo "  発見した引用数: $TOTAL_CITATIONS"

    # 引用番号の連続性チェック
    PREV=0
    for NUM in $CITATIONS; do
        if [ $((PREV + 1)) -lt $NUM ] && [ $PREV -ne 0 ]; then
            for ((i=PREV+1; i<NUM; i++)); do
                MISSING_CITATIONS+=($i)
            done
        fi
        PREV=$NUM
    done

    if [ ${#MISSING_CITATIONS[@]} -gt 0 ]; then
        echo -e "${YELLOW}  警告: 欠番の引用番号: ${MISSING_CITATIONS[*]}${NC}"
    fi
else
    echo -e "${YELLOW}  警告: 引用が見つかりません${NC}"
fi

# 参考文献の抽出
echo -e "${GREEN}参考文献をチェック中...${NC}"
REFERENCES=$(grep '^\[\^[0-9]\+\]:' "$REPORT_FILE" | sed 's/^\[\^\([0-9]\+\)\]:.*/\1/' | sort -nu)

# URL必須チェック
echo -e "${GREEN}参考文献のURL必須チェック中...${NC}"
REFERENCES_WITHOUT_URL=()
while IFS= read -r line; do
    if [[ $line =~ ^\[\^[0-9]+\]: ]]; then
        # URLパターンをチェック（http/https）
        if ! echo "$line" | grep -q 'https\?://'; then
            REF_NUM=$(echo "$line" | sed 's/^\[\^\([0-9]\+\)\]:.*/\1/')
            REFERENCES_WITHOUT_URL+=($REF_NUM)
        fi
    fi
done < "$REPORT_FILE"

if [ ${#REFERENCES_WITHOUT_URL[@]} -gt 0 ]; then
    echo -e "${RED}  エラー: URLが記載されていない参考文献: ${REFERENCES_WITHOUT_URL[*]}${NC}"
fi

if [ -n "$REFERENCES" ]; then
    TOTAL_REFERENCES=$(echo "$REFERENCES" | wc -l)
    echo "  発見した参考文献数: $TOTAL_REFERENCES"

    # 未使用の参考文献チェック
    for REF in $REFERENCES; do
        if ! echo "$CITATIONS" | grep -q "^$REF$"; then
            UNUSED_REFERENCES+=($REF)
        fi
    done

    if [ ${#UNUSED_REFERENCES[@]} -gt 0 ]; then
        echo -e "${YELLOW}  警告: 未使用の参考文献: ${UNUSED_REFERENCES[*]}${NC}"
    fi
else
    echo -e "${YELLOW}  警告: 参考文献リストが見つかりません${NC}"
fi

# 引用に対応する参考文献の存在チェック
echo -e "${GREEN}引用と参考文献の対応をチェック中...${NC}"
MISSING_REFS=()
for CIT in $CITATIONS; do
    if ! echo "$REFERENCES" | grep -q "^$CIT$"; then
        MISSING_REFS+=($CIT)
    fi
done

if [ ${#MISSING_REFS[@]} -gt 0 ]; then
    echo -e "${RED}  エラー: 参考文献が定義されていない引用: ${MISSING_REFS[*]}${NC}"
fi

# 相互参照チェック
echo -e "${GREEN}相互参照をチェック中...${NC}"
SECTION_REFS=$(grep -n '第[0-9]\+章\|第[0-9]\+節\|図[0-9]\+\|表[0-9]\+\|付録[A-Z]\+' "$REPORT_FILE" | wc -l)
CROSS_REFS=$(grep -n '\[.*参照\]\|\[.*章.*\]\|\[.*図.*\]\|\[.*表.*\]' "$REPORT_FILE" | wc -l)

echo "  発見したセクション・図表: $SECTION_REFS個"
echo "  発見した相互参照: $CROSS_REFS個"

# 相互参照推奨チェック（セクションに対する参照が少ない場合）
if [ $SECTION_REFS -gt 3 ] && [ $CROSS_REFS -lt $((SECTION_REFS / 3)) ]; then
    echo -e "${YELLOW}  推奨: セクション間の相互参照を増やすことで読みやすさが向上します${NC}"
fi

# URLチェック（オプション）
if [ "$CHECK_URLS" == "--check-urls" ]; then
    echo -e "${GREEN}URLの有効性をチェック中...${NC}"
    URLS=$(grep -o 'https\?://[^)]*' "$REPORT_FILE" | sort -u)

    if [ -n "$URLS" ]; then
        for URL in $URLS; do
            # HEADリクエストでURLの有効性を確認
            if curl -f -s --head "$URL" > /dev/null; then
                echo -e "  ${GREEN}✓${NC} $URL"
            else
                echo -e "  ${RED}✗${NC} $URL"
                BROKEN_URLS+=("$URL")
            fi
        done

        if [ ${#BROKEN_URLS[@]} -gt 0 ]; then
            echo -e "${YELLOW}  警告: アクセスできないURL: ${#BROKEN_URLS[@]}件${NC}"
        fi
    else
        echo "  URLが見つかりません"
    fi
fi

# 結果サマリー
echo ""
echo -e "${BLUE}=== チェック結果サマリー ===${NC}"
echo "引用数: $TOTAL_CITATIONS"
echo "参考文献数: $TOTAL_REFERENCES"

ERROR_COUNT=0
WARNING_COUNT=0

if [ ${#MISSING_REFS[@]} -gt 0 ]; then
    echo -e "${RED}エラー:${NC}"
    echo "  - 参考文献が未定義の引用: ${#MISSING_REFS[@]}件"
    ERROR_COUNT=$((ERROR_COUNT + ${#MISSING_REFS[@]}))
fi

if [ ${#REFERENCES_WITHOUT_URL[@]} -gt 0 ]; then
    if [ $ERROR_COUNT -eq 0 ]; then
        echo -e "${RED}エラー:${NC}"
    fi
    echo "  - URLが記載されていない参考文献: ${#REFERENCES_WITHOUT_URL[@]}件"
    ERROR_COUNT=$((ERROR_COUNT + ${#REFERENCES_WITHOUT_URL[@]}))
fi

if [ ${#MISSING_CITATIONS[@]} -gt 0 ] || [ ${#UNUSED_REFERENCES[@]} -gt 0 ] || [ ${#BROKEN_URLS[@]} -gt 0 ]; then
    echo -e "${YELLOW}警告:${NC}"
    if [ ${#MISSING_CITATIONS[@]} -gt 0 ]; then
        echo "  - 欠番の引用番号: ${#MISSING_CITATIONS[@]}件"
        WARNING_COUNT=$((WARNING_COUNT + ${#MISSING_CITATIONS[@]}))
    fi
    if [ ${#UNUSED_REFERENCES[@]} -gt 0 ]; then
        echo "  - 未使用の参考文献: ${#UNUSED_REFERENCES[@]}件"
        WARNING_COUNT=$((WARNING_COUNT + ${#UNUSED_REFERENCES[@]}))
    fi
    if [ ${#BROKEN_URLS[@]} -gt 0 ]; then
        echo "  - アクセスできないURL: ${#BROKEN_URLS[@]}件"
        WARNING_COUNT=$((WARNING_COUNT + ${#BROKEN_URLS[@]}))
    fi
fi

# 最終判定
echo ""
if [ $ERROR_COUNT -eq 0 ] && [ $WARNING_COUNT -eq 0 ]; then
    echo -e "${GREEN}✓ すべてのチェックに合格しました${NC}"
    exit 0
elif [ $ERROR_COUNT -eq 0 ]; then
    echo -e "${YELLOW}⚠ $WARNING_COUNT 件の警告があります${NC}"
    exit 0
else
    echo -e "${RED}✗ $ERROR_COUNT 件のエラーがあります${NC}"
    exit 1
fi