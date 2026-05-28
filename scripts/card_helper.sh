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
#
#   card_helper.sh init --chinese "..." --english "..." --surname "..." --given "..." \
#                       --title "..." --email "..." --mobile "..." --office-ext "..."
#       建資料夾 + 複製模板 + 開 Illustrator + 輪詢 + 寫 sidecar /tmp/sv_card_fields.json
#       sidecar 內含 Step 2 (fields) + Step 3 (artifacts) 兩區塊，後續步驟皆從此讀取
#
#   card_helper.sh artifacts [args...]
#       無 args → 預設讀 /tmp/sv_card_fields.json 的 artifacts 區塊
#       有 args → forward 給 make_card_artifacts.py（向後相容）
#
#   card_helper.sh save-original <dest-folder> <basename>
#       從 /tmp 搬 output_original.ai 到 <dest-folder>/<basename>.ai
#       並產生 <dest-folder>/<basename>.jpg（2000×780 預覽）
#
#   card_helper.sh save-ol <dest-folder> <basename>
#       從 /tmp 搬 output_ol.ai 到 <dest-folder>/OL-<basename>.ai
#
#   card_helper.sh finalize <dest-folder> <basename>
#       GATE 後一次收尾：搬 original + JPG + 搬 OL + 列產出
#       （等同 save-original 再 save-ol，配合 finalize.jsx 使用）
#
#   card_helper.sh upload-vcard <vcf-path>
#       透過 curl + FTP 上傳 vcf 到 Transmit favorite「Streetvoice」對應 server 的 /vcard/。
#       host/user 從 Transmit favorite 動態讀，密碼存 macOS Keychain（首次跑會 prompt）。
#       FTP STOR 預設覆蓋同名檔。
#
# basename 格式範例：20260527-王小明_Ming Wang
# dest-folder 格式範例：~/Documents/SV-名片/王小明_Ming Wang
# sidecar 路徑：/tmp/sv_card_fields.json

set -e

# 載入使用者環境變數（install.sh 會寫入此檔）
[ -f "$HOME/.config/sv-card/env" ] && . "$HOME/.config/sv-card/env"

# 可由環境變數或 ~/.config/sv-card/env 覆寫
SV_CARD_SKILL_DIR="${SV_CARD_SKILL_DIR:-$HOME/.claude/skills/sv-card}"
SV_TEMPLATE="${SV_TEMPLATE:-$SV_CARD_SKILL_DIR/templates/20260522-王小明.ai}"
SV_OUTPUT_BASE="${SV_OUTPUT_BASE:-$HOME/Documents/SV-名片}"
SV_SIDECAR="${SV_SIDECAR:-/tmp/sv_card_fields.json}"

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

    artifacts)
        # 無 args → 預設讀 sidecar；有 args → 沿用 forward 模式
        if [ $# -eq 0 ]; then
            if [ ! -f "$SV_SIDECAR" ]; then
                echo "ERROR: 找不到 sidecar: $SV_SIDECAR（需先跑 init）" >&2
                exit 1
            fi
            exec python3 "$SV_CARD_SKILL_DIR/scripts/make_card_artifacts.py" --from "$SV_SIDECAR"
        else
            exec python3 "$SV_CARD_SKILL_DIR/scripts/make_card_artifacts.py" "$@"
        fi
        ;;

    confirm-firstrun)
        out="$1"
        if [ -z "$out" ]; then
            echo "ERROR: confirm-firstrun 需要 <output-path>" >&2
            exit 1
        fi
        # 處理 ~ 展開（避免 eval 注入；不能用 ${out#~/} 因為 bash 會對 pattern 內的 ~ 做 tilde expansion）
        case "$out" in
            "~")    out="$HOME" ;;
            "~/"*)  out="$HOME${out:1}" ;;
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
        # 解析 named args
        chinese_full=""
        english_name=""
        surname=""
        given=""
        title=""
        email=""
        mobile=""
        office_ext=""
        while [ $# -gt 0 ]; do
            case "$1" in
                --chinese)    chinese_full="$2"; shift 2 ;;
                --english)    english_name="$2"; shift 2 ;;
                --surname)    surname="$2"; shift 2 ;;
                --given)      given="$2"; shift 2 ;;
                --title)      title="$2"; shift 2 ;;
                --email)      email="$2"; shift 2 ;;
                --mobile)     mobile="$2"; shift 2 ;;
                --office-ext) office_ext="$2"; shift 2 ;;
                *)
                    echo "ERROR: init 不認識的參數: $1" >&2
                    exit 1 ;;
            esac
        done

        # 必填檢查
        missing=""
        for kv in "chinese:$chinese_full" "english:$english_name" "surname:$surname" \
                  "given:$given" "title:$title" "email:$email" "mobile:$mobile" \
                  "office-ext:$office_ext"; do
            k="${kv%%:*}"; v="${kv#*:}"
            [ -z "$v" ] && missing="$missing --$k"
        done
        if [ -n "$missing" ]; then
            echo "ERROR: init 缺少必填參數:$missing" >&2
            echo "用法: init --chinese ... --english ... --surname ... --given ..." >&2
            echo "          --title ... --email ... --mobile ... --office-ext ..." >&2
            exit 1
        fi

        name_folder="${chinese_full}_${english_name}"
        dest_dir="$SV_OUTPUT_BASE/$name_folder"
        today=$(date +%Y%m%d)
        new_file="$dest_dir/${today}-${name_folder}.ai"

        mkdir -p "$dest_dir"
        cp -L "$SV_TEMPLATE" "$new_file"
        echo "✅ 模板已複製: $new_file"

        # 寫 sidecar JSON（推導 mobile_display、vcf_name、ph_phone_office）
        SURNAME="$surname" GIVEN="$given" EN="$english_name" \
        TITLE="$title" EMAIL="$email" MOBILE="$mobile" \
        OFFICE_EXT="$office_ext" DEST_DIR="$dest_dir" \
        python3 - <<'PYEOF' > "$SV_SIDECAR"
import json, os
mobile_vcard = os.environ["MOBILE"]
mobile_display = mobile_vcard.replace(" ", "-")
en = os.environ["EN"]
vcf_name = en.replace(" ", "") + ".vcf"
data = {
    "fields": {
        "PH_NAME_CN_SURNAME": os.environ["SURNAME"],
        "PH_NAME_CN_GIVEN":   os.environ["GIVEN"],
        "PH_NAME_EN":         en,
        "PH_TITLE":           os.environ["TITLE"],
        "PH_PHONE_OFFICE":    "+886-2-2741-7065#" + os.environ["OFFICE_EXT"],
        "PH_PHONE_MOBILE":    mobile_display,
        "PH_EMAIL":           os.environ["EMAIL"],
    },
    "artifacts": {
        "surname":  os.environ["SURNAME"],
        "given":    os.environ["GIVEN"],
        "en":       en,
        "title":    os.environ["TITLE"],
        "email":    os.environ["EMAIL"],
        "mobile":   mobile_vcard,
        "folder":   os.environ["DEST_DIR"],
        "vcf_name": vcf_name,
    },
}
print(json.dumps(data, ensure_ascii=False, indent=2))
PYEOF
        echo "✅ sidecar 寫入: $SV_SIDECAR"

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
        echo
        echo "📁 最終產出："
        ls -la "$dest/"
        ;;

    upload-vcard)
        vcf="$1"
        if [ -z "$vcf" ] || [ ! -f "$vcf" ]; then
            echo "ERROR: upload-vcard 需要 <vcf-path>（檔案需存在）" >&2
            exit 1
        fi

        fav_name="${SV_TRANSMIT_FAVORITE:-Streetvoice}"
        remote_dir="${SV_TRANSMIT_REMOTE_DIR:-/vcard}"
        kc_label="sv-card upload (${fav_name})"

        # 從 Transmit favorite 動態讀 host + user（不寫死，跨同事通用）
        host=$(osascript -e "tell application \"Transmit\" to return address of (first favorite whose name is \"${fav_name}\")" 2>/dev/null || true)
        user=$(osascript -e "tell application \"Transmit\" to return user name of (first favorite whose name is \"${fav_name}\")" 2>/dev/null || true)
        if [ -z "$host" ] || [ -z "$user" ]; then
            echo "ERROR: 找不到 Transmit favorite \"${fav_name}\"（需先在 Transmit 內建好同名 favorite）" >&2
            exit 1
        fi

        echo "📤 上傳目標：ftp://${user}@${host}${remote_dir}/"

        # 從 Keychain 拿密碼
        password=$(security find-internet-password -s "$host" -a "$user" -l "$kc_label" -w 2>/dev/null || true)

        if [ -z "$password" ]; then
            # 首次：透過 osascript dialog 跟使用者要密碼
            echo "🔐 首次上傳，請在 dialog 輸入密碼（會存到 macOS Keychain，下次靜默使用）"
            password=$(osascript <<APPLESCRIPT 2>/dev/null || true
try
    set p to text returned of (display dialog "請輸入 Transmit favorite「${fav_name}」的 FTP 密碼

host: ${host}
user: ${user}

密碼會存到 macOS Keychain，下次不再詢問。" with title "sv-card 首次上傳設定" default answer "" with hidden answer)
    return p
on error
    return ""
end try
APPLESCRIPT
)
            if [ -z "$password" ]; then
                echo "❌ 使用者取消輸入密碼" >&2
                exit 1
            fi
            security add-internet-password -s "$host" -a "$user" -l "$kc_label" -w "$password" -U
            echo "✅ 密碼已存入 macOS Keychain（label：${kc_label}）"
        fi

        vcf_basename=$(basename "$vcf")

        # 上傳前先查 server 是否已有同名檔（區分「新上傳」vs「覆蓋舊檔」）
        existed_before=0
        if curl -sS --list-only "ftp://${host}${remote_dir}/" --user "${user}:${password}" 2>/dev/null \
               | grep -qFx "$vcf_basename"; then
            existed_before=1
        fi

        # curl 上傳（FTP STOR 預設覆蓋同名檔）
        echo "📤 curl 上傳：$vcf_basename"
        if curl -sS -fS --ftp-create-dirs \
                --upload-file "$vcf" \
                "ftp://${host}${remote_dir}/${vcf_basename}" \
                --user "${user}:${password}"; then
            if [ "$existed_before" = "1" ]; then
                echo "✅ vCard 已上傳 server 並覆蓋舊檔"
            else
                echo "✅ vCard 已上傳 server"
            fi
            echo "📋 公開 URL：http://${host}${remote_dir}/${vcf_basename}"
        else
            curl_exit=$?
            if [ "$existed_before" = "1" ]; then
                echo "❌ 目前您的 Server 權限無法覆蓋原檔，請洽資訊部同仁。" >&2
                echo "  → 對應檔案：${vcf_basename}（server 上已存在但 owner 非當前帳號 ${user}）" >&2
            else
                echo "❌ 上傳失敗（curl exit ${curl_exit}）" >&2
                echo "  → 若密碼錯誤，請執行：security delete-internet-password -s \"${host}\" -a \"${user}\" -l \"${kc_label}\"" >&2
                echo "  → 然後重跑 upload-vcard 會再次 prompt 密碼" >&2
            fi
            exit 1
        fi
        ;;

    finalize)
        # GATE 後合併收尾：等同 save-original 後接 save-ol
        # 配合 finalize.jsx 使用（jsx 已產出 /tmp/output_original.ai + /tmp/output_ol.ai）
        dest="$1"
        basename="$2"
        if [ -z "$dest" ] || [ -z "$basename" ]; then
            echo "ERROR: finalize 需要 <dest-folder> <basename>" >&2
            exit 1
        fi

        # 搬原檔 + 匯 JPG
        mv /tmp/output_original.ai "$dest/${basename}.ai"
        cp "$dest/${basename}.ai" /tmp/temp.pdf
        sips -s format jpeg --resampleHeightWidth 780 2000 -s formatOptions 90 /tmp/temp.pdf --out /tmp/preview.jpg > /dev/null
        mv /tmp/preview.jpg "$dest/${basename}.jpg"
        rm /tmp/temp.pdf
        echo "✅ 原檔 + JPG → $dest/"

        # 搬 OL
        mv /tmp/output_ol.ai "$dest/OL-${basename}.ai"
        echo "✅ OL → $dest/OL-${basename}.ai"
        echo
        echo "📁 最終產出："
        ls -la "$dest/"
        ;;

    *)
        echo "Usage:" >&2
        echo "  $0 check-firstrun" >&2
        echo "  $0 confirm-firstrun <output-path>" >&2
        echo "  $0 init --chinese ... --english ... --surname ... --given ..." >&2
        echo "              --title ... --email ... --mobile ... --office-ext ..." >&2
        echo "  $0 artifacts [args...]" >&2
        echo "  $0 save-original <dest-folder> <basename>" >&2
        echo "  $0 save-ol <dest-folder> <basename>" >&2
        echo "  $0 finalize <dest-folder> <basename>" >&2
        echo "  $0 upload-vcard <vcf-path>" >&2
        exit 1
        ;;
esac
