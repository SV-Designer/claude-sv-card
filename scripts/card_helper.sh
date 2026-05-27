#!/bin/bash
#
# SV 名片自動化流程的 Bash 操作合集
# 由 Claude Code 在 SV_名片自動化製作 SOP 中呼叫
#
# 用法：
#   card_helper.sh check-firstrun
#       印 "run-step0" (SV_OUTPUT_CONFIRMED != 1) 或 "skip-step0"
#
#   card_helper.sh confirm-firstrun <output-path>
#       首次製作確認：mkdir + open Finder + 寫 env (SV_OUTPUT_CONFIRMED=1)
#       <output-path> 可帶 ~ 或絕對路徑
#
#   card_helper.sh init <chinese-full-name> <english-name>
#       建資料夾 + 複製模板 + 開 Illustrator + 輪詢直到 doc 就緒
#
#   card_helper.sh save-original <dest-folder> <basename>
#       從 /tmp 搬 output_original.ai 到 <dest-folder>/<basename>.ai
#       並產生 <dest-folder>/<basename>.jpg（2000×780 預覽）
#
#   card_helper.sh save-ol <dest-folder> <basename>
#       從 /tmp 搬 output_ol.ai 到 <dest-folder>/OL-<basename>.ai
#
# basename 格式範例：20260527-王小明_Ming Wang
# dest-folder 格式範例：~/Documents/SV-名片/王小明_Ming Wang

set -e

# 載入使用者環境變數（install.sh 會寫入此檔）
[ -f "$HOME/.config/sv-card/env" ] && . "$HOME/.config/sv-card/env"

# 可由環境變數或 ~/.config/sv-card/env 覆寫
SV_CARD_SKILL_DIR="${SV_CARD_SKILL_DIR:-$HOME/.claude/skills/sv-card}"
SV_TEMPLATE="${SV_TEMPLATE:-$SV_CARD_SKILL_DIR/templates/20260522-王小明.ai}"
SV_OUTPUT_BASE="${SV_OUTPUT_BASE:-$HOME/Documents/SV-名片}"

if [ ! -f "$SV_TEMPLATE" ]; then
    echo "ERROR: 找不到模板 .ai 檔: $SV_TEMPLATE" >&2
    echo "  → 請執行 install.sh，或設定 SV_TEMPLATE 環境變數指向實際路徑" >&2
    exit 1
fi

cmd="$1"
shift || true

case "$cmd" in
    check-firstrun)
        # 印 "run-step0" 代表需走首次確認流程；"skip-step0" 代表跳過
        if [ "$SV_OUTPUT_CONFIRMED" = "1" ]; then
            echo "skip-step0"
        else
            echo "run-step0"
        fi
        ;;

    confirm-firstrun)
        out="$1"
        if [ -z "$out" ]; then
            echo "ERROR: confirm-firstrun 需要 <output-path>" >&2
            exit 1
        fi
        # 處理 ~ 展開（避免 eval 注入）
        case "$out" in
            "~")    out="$HOME" ;;
            "~/"*)  out="$HOME/${out#~/}" ;;
        esac
        mkdir -p "$out"
        open "$out"
        mkdir -p "$HOME/.config/sv-card"
        tmp="$HOME/.config/sv-card/env.tmp"
        cat > "$tmp" <<EOF
# sv-card 使用者偏好（由首次製作名片流程寫入，可手動編輯）
SV_OUTPUT_BASE="$out"
SV_TEMPLATE="$SV_TEMPLATE"
SV_OUTPUT_CONFIRMED=1
EOF
        mv "$tmp" "$HOME/.config/sv-card/env"
        echo "✅ env 寫入 + Finder 已開啟 $out"
        ;;

    init)
        chinese_full="$1"
        english_name="$2"
        if [ -z "$chinese_full" ] || [ -z "$english_name" ]; then
            echo "ERROR: init 需要 <chinese-full> <english-name>" >&2
            exit 1
        fi

        name_folder="${chinese_full}_${english_name}"
        dest_dir="$SV_OUTPUT_BASE/$name_folder"
        today=$(date +%Y%m%d)
        new_file="$dest_dir/${today}-${name_folder}.ai"

        mkdir -p "$dest_dir"
        cp -L "$SV_TEMPLATE" "$new_file"
        echo "✅ 模板已複製: $new_file"

        if pgrep -x "Adobe Illustrator" > /dev/null; then
            echo "⚠️ Illustrator 已在運行，open 可能被歡迎頁攔截。建議冷啟動。"
        fi

        open -a "Adobe Illustrator" "$new_file"
        echo "✅ open 已發送，輪詢 doc 就緒中..."

        for i in $(seq 1 60); do
            sleep 1
            name=$(osascript -e 'tell application "Adobe Illustrator" to if (count of documents) > 0 then return name of current document' 2>/dev/null || echo "")
            if [ -n "$name" ]; then
                echo "✅ ${i}s: doc=$name"
                echo "BASENAME=${today}-${name_folder}"
                echo "DEST_DIR=$dest_dir"
                exit 0
            fi
        done
        echo "❌ 60s 內 Illustrator 未就緒" >&2
        exit 1
        ;;

    save-original)
        dest="$1"
        basename="$2"
        if [ -z "$dest" ] || [ -z "$basename" ]; then
            echo "ERROR: save-original 需要 <dest-folder> <basename>" >&2
            exit 1
        fi

        mv /tmp/output_original.ai "$dest/${basename}.ai"
        cp "$dest/${basename}.ai" /tmp/temp.pdf
        sips -s format jpeg --resampleHeightWidth 780 2000 -s formatOptions 90 /tmp/temp.pdf --out /tmp/preview.jpg > /dev/null
        mv /tmp/preview.jpg "$dest/${basename}.jpg"
        rm /tmp/temp.pdf
        echo "✅ 原檔 + JPG → $dest/"
        ;;

    save-ol)
        dest="$1"
        basename="$2"
        if [ -z "$dest" ] || [ -z "$basename" ]; then
            echo "ERROR: save-ol 需要 <dest-folder> <basename>" >&2
            exit 1
        fi

        mv /tmp/output_ol.ai "$dest/OL-${basename}.ai"
        echo "✅ OL → $dest/OL-${basename}.ai"
        ;;

    *)
        echo "Usage:" >&2
        echo "  $0 check-firstrun" >&2
        echo "  $0 confirm-firstrun <output-path>" >&2
        echo "  $0 init <chinese-full> <english-name>" >&2
        echo "  $0 save-original <dest-folder> <basename>" >&2
        echo "  $0 save-ol <dest-folder> <basename>" >&2
        exit 1
        ;;
esac
