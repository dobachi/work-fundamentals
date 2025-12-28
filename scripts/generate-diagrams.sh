#!/bin/bash

# 図表生成スクリプト - コマンドラインからSVG図表を生成
# 使用法: ./generate-diagrams.sh [type] [input] [output] [options]

set -e

# カラー出力の定義
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# プロジェクトルートディレクトリ
PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DIAGRAMS_DIR="$PROJECT_ROOT/sources/diagrams"
OUTPUT_DIR="$PROJECT_ROOT/sources/diagrams/generated"

# 図表タイプの定義
SUPPORTED_TYPES=("plantuml" "graphviz" "mermaid" "dot")

# 使用法の表示
show_usage() {
    cat << EOF
使用法: $0 [type] [input] [output] [options]

図表タイプ:
  plantuml    : PlantUML (.puml, .plantuml)
  graphviz    : Graphviz DOT (.dot, .gv)
  mermaid     : Mermaid (.mmd, .mermaid)
  dot         : Graphviz DOT (alias for graphviz)

引数:
  type        : 図表タイプ (plantuml|graphviz|mermaid|dot)
  input       : 入力ファイル（拡張子で自動判定も可能）
  output      : 出力SVGファイル（省略時は自動生成）

オプション:
  --theme THEME       : テーマ指定（PlantUMLのみ）
  --style STYLE       : スタイル指定
  --width WIDTH       : 出力幅指定（Mermaidのみ）
  --height HEIGHT     : 出力高さ指定（Mermaidのみ）
  --inkscape          : 生成後にInkscapeで開く
  --preview           : 生成後にプレビューを表示
  --help              : このヘルプを表示

ディレクトリ構造:
  sources/diagrams/           # 入力ファイル
  ├── plantuml/              # PlantUMLソースファイル
  ├── graphviz/              # Graphvizソースファイル
  ├── mermaid/               # Mermaidソースファイル
  └── generated/             # 生成されたSVGファイル

例:
  $0 plantuml architecture.puml
  $0 graphviz network.dot network-diagram.svg
  $0 mermaid flow.mmd --width 800 --inkscape
  $0 plantuml system.puml --theme blueprint

自動判定例:
  $0 auto sources/diagrams/plantuml/system.puml
  $0 auto sources/diagrams/graphviz/network.dot

Quarto統合:
  ![図表説明](sources/diagrams/generated/diagram.svg){#fig-diagram}

Inkscape編集:
  生成されたSVGファイルはInkscapeで高品質編集可能

EOF
}

# 依存関係のチェック
check_dependencies() {
    local missing_tools=()
    local type="$1"

    case "$type" in
        "plantuml")
            if ! command -v java &> /dev/null; then
                missing_tools+=("java")
            fi
            if [ ! -f "$PROJECT_ROOT/tools/plantuml.jar" ] && ! command -v plantuml &> /dev/null; then
                missing_tools+=("plantuml.jar または plantuml")
            fi
            ;;
        "graphviz"|"dot")
            if ! command -v dot &> /dev/null; then
                missing_tools+=("graphviz (dot command)")
            fi
            ;;
        "mermaid")
            if ! command -v mmdc &> /dev/null; then
                missing_tools+=("@mermaid-js/mermaid-cli")
            fi
            ;;
    esac

    if [ ${#missing_tools[@]} -gt 0 ]; then
        echo -e "${RED}エラー: 以下のツールがインストールされていません:${NC}"
        for tool in "${missing_tools[@]}"; do
            echo "  - $tool"
        done
        echo ""
        echo "インストール方法:"
        case "$type" in
            "plantuml")
                echo "  Java: sudo apt-get install openjdk-11-jre"
                echo "  PlantUML: wget https://github.com/plantuml/plantuml/releases/latest/download/plantuml.jar -O tools/plantuml.jar"
                ;;
            "graphviz"|"dot")
                echo "  Ubuntu/Debian: sudo apt-get install graphviz"
                echo "  macOS: brew install graphviz"
                ;;
            "mermaid")
                echo "  Node.js: npm install -g @mermaid-js/mermaid-cli"
                ;;
        esac
        return 1
    fi
}

# ファイルタイプの自動判定
detect_file_type() {
    local input_file="$1"
    local extension="${input_file##*.}"

    case "$extension" in
        "puml"|"plantuml")
            echo "plantuml"
            ;;
        "dot"|"gv")
            echo "graphviz"
            ;;
        "mmd"|"mermaid")
            echo "mermaid"
            ;;
        *)
            # ファイル内容で判定
            if grep -q "@startuml\|@startmindmap\|@startgantt" "$input_file" 2>/dev/null; then
                echo "plantuml"
            elif grep -q "digraph\|graph\|strict" "$input_file" 2>/dev/null; then
                echo "graphviz"
            elif grep -q "graph\|flowchart\|sequenceDiagram" "$input_file" 2>/dev/null; then
                echo "mermaid"
            else
                echo "unknown"
            fi
            ;;
    esac
}

# PlantUML SVG生成
generate_plantuml_svg() {
    local input="$1"
    local output="$2"
    local theme="$3"

    echo -e "${BLUE}PlantUML SVG生成中...${NC}"

    local plantuml_cmd=""
    if [ -f "$PROJECT_ROOT/tools/plantuml.jar" ]; then
        plantuml_cmd="java -jar $PROJECT_ROOT/tools/plantuml.jar"
    elif command -v plantuml &> /dev/null; then
        plantuml_cmd="plantuml"
    else
        echo -e "${RED}エラー: PlantUMLが見つかりません${NC}"
        return 1
    fi

    # テーマ指定がある場合は一時ファイルを作成
    local temp_input="$input"
    if [ -n "$theme" ]; then
        temp_input="$(mktemp)"
        echo "!theme $theme" > "$temp_input"
        cat "$input" >> "$temp_input"
    fi

    # SVG生成
    $plantuml_cmd -tsvg -o "$(dirname "$output")" "$temp_input"

    # 出力ファイル名の調整
    local generated_file="$(dirname "$output")/$(basename "$temp_input" | sed 's/\.[^.]*$//')"
    if [ -f "${generated_file}.svg" ]; then
        mv "${generated_file}.svg" "$output"
    fi

    # 一時ファイルのクリーンアップ
    if [ "$temp_input" != "$input" ]; then
        rm -f "$temp_input"
    fi

    echo -e "${GREEN}✓ PlantUML SVG生成完了: $output${NC}"
}

# Graphviz SVG生成
generate_graphviz_svg() {
    local input="$1"
    local output="$2"

    echo -e "${BLUE}Graphviz SVG生成中...${NC}"

    dot -Tsvg "$input" -o "$output"

    echo -e "${GREEN}✓ Graphviz SVG生成完了: $output${NC}"
}

# Mermaid SVG生成
generate_mermaid_svg() {
    local input="$1"
    local output="$2"
    local width="$3"
    local height="$4"

    echo -e "${BLUE}Mermaid SVG生成中...${NC}"

    local mermaid_cmd="mmdc -i $input -o $output"

    if [ -n "$width" ]; then
        mermaid_cmd="$mermaid_cmd --width $width"
    fi
    if [ -n "$height" ]; then
        mermaid_cmd="$mermaid_cmd --height $height"
    fi

    eval $mermaid_cmd

    echo -e "${GREEN}✓ Mermaid SVG生成完了: $output${NC}"
}

# ディレクトリ構造の初期化
init_directories() {
    mkdir -p "$DIAGRAMS_DIR"/{plantuml,graphviz,mermaid}
    mkdir -p "$OUTPUT_DIR"
    mkdir -p "$PROJECT_ROOT/tools"
}

# 出力ファイル名の自動生成
generate_output_filename() {
    local input="$1"
    local type="$2"

    local basename=$(basename "$input" | sed 's/\.[^.]*$//')
    echo "$OUTPUT_DIR/${basename}.svg"
}

# メイン処理
main() {
    local diagram_type=""
    local input_file=""
    local output_file=""
    local theme=""
    local style=""
    local width=""
    local height=""
    local open_inkscape=false
    local show_preview=false

    # 引数の解析
    while [[ $# -gt 0 ]]; do
        case $1 in
            --theme)
                theme="$2"
                shift 2
                ;;
            --style)
                style="$2"
                shift 2
                ;;
            --width)
                width="$2"
                shift 2
                ;;
            --height)
                height="$2"
                shift 2
                ;;
            --inkscape)
                open_inkscape=true
                shift
                ;;
            --preview)
                show_preview=true
                shift
                ;;
            --help)
                show_usage
                exit 0
                ;;
            -*)
                echo -e "${RED}エラー: 不明なオプション '$1'${NC}"
                show_usage
                exit 1
                ;;
            *)
                if [ -z "$diagram_type" ]; then
                    diagram_type="$1"
                elif [ -z "$input_file" ]; then
                    input_file="$1"
                elif [ -z "$output_file" ]; then
                    output_file="$1"
                fi
                shift
                ;;
        esac
    done

    # 引数の検証
    if [ -z "$diagram_type" ] || [ -z "$input_file" ]; then
        echo -e "${RED}エラー: 図表タイプと入力ファイルは必須です${NC}"
        show_usage
        exit 1
    fi

    # ディレクトリの初期化
    init_directories

    # 入力ファイルの存在確認
    if [ ! -f "$input_file" ]; then
        echo -e "${RED}エラー: 入力ファイル '$input_file' が見つかりません${NC}"
        exit 1
    fi

    # 自動判定モード
    if [ "$diagram_type" = "auto" ]; then
        diagram_type=$(detect_file_type "$input_file")
        if [ "$diagram_type" = "unknown" ]; then
            echo -e "${RED}エラー: ファイルタイプを自動判定できませんでした${NC}"
            exit 1
        fi
        echo -e "${CYAN}自動判定結果: $diagram_type${NC}"
    fi

    # サポートされているタイプの確認
    if [[ ! " ${SUPPORTED_TYPES[@]} " =~ " ${diagram_type} " ]]; then
        echo -e "${RED}エラー: サポートされていない図表タイプ: $diagram_type${NC}"
        echo "サポートされているタイプ: ${SUPPORTED_TYPES[*]}"
        exit 1
    fi

    # 出力ファイル名の生成
    if [ -z "$output_file" ]; then
        output_file=$(generate_output_filename "$input_file" "$diagram_type")
    fi

    # 依存関係のチェック
    if ! check_dependencies "$diagram_type"; then
        exit 1
    fi

    # 図表生成の実行
    echo -e "${YELLOW}図表生成開始${NC}"
    echo "入力: $input_file"
    echo "出力: $output_file"
    echo "タイプ: $diagram_type"

    case "$diagram_type" in
        "plantuml")
            generate_plantuml_svg "$input_file" "$output_file" "$theme"
            ;;
        "graphviz"|"dot")
            generate_graphviz_svg "$input_file" "$output_file"
            ;;
        "mermaid")
            generate_mermaid_svg "$input_file" "$output_file" "$width" "$height"
            ;;
    esac

    # 生成ファイルの確認
    if [ -f "$output_file" ]; then
        local file_size=$(du -h "$output_file" | cut -f1)
        echo -e "${GREEN}✓ SVG生成成功: $output_file ($file_size)${NC}"

        # Quarto統合のヒント
        local relative_path=$(realpath --relative-to="$PROJECT_ROOT" "$output_file")
        echo ""
        echo -e "${CYAN}Quarto統合コード:${NC}"
        echo "![図表説明]($relative_path){#fig-$(basename "$output_file" .svg)}"

        # Inkscapeで開く
        if [ "$open_inkscape" = true ] && command -v inkscape &> /dev/null; then
            echo -e "${BLUE}Inkscapeで開いています...${NC}"
            inkscape "$output_file" &
        fi

        # プレビュー表示
        if [ "$show_preview" = true ] && command -v xdg-open &> /dev/null; then
            xdg-open "$output_file" &
        fi

    else
        echo -e "${RED}エラー: SVG生成に失敗しました${NC}"
        exit 1
    fi
}

# スクリプト実行
main "$@"