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
#                       --title "..." --email "..." [--mobile "..."] [--office-ext "..."]
#       建資料夾 + 複製模板 + 開 Illustrator + 輪詢 + 寫 sidecar /tmp/sv_card_fields.json
#       sidecar 內含 Step 2 (fields) + Step 3 (artifacts) 兩區塊，後續步驟皆從此讀取
#       --mobile 空（或不傳）→ 用無手機版模板（SV_TEMPLATE_NO_MOBILE）；vCard 跳過 TEL CELL
#       --office-ext 空（或不傳）→ 新版分機框 PH_PHONE_EXT 留空；公司電話固定靜態於模板
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
#   card_helper.sh upload-vcard [--check-only] <vcf-path>
#       透過 curl + FTP 上傳 vcf 到 Transmit favorite「Streetvoice」對應 server 的 /vcard/。
#       host/user 從 Transmit favorite 動態讀，密碼存 macOS Keychain（首次跑會 prompt）。
#       FTP STOR 預設覆蓋同名檔；對 transient 550 自動 retry 一次。
#       --check-only：只做「拿密碼 + preflight + 查 server」，不上傳。
#                     印 exists / new 並 exit 0，供 SKILL.md Step 9a 預檢判斷。
#
#   card_helper.sh verify-vcard <vcf-path>
#       抓 server 上同名 vcf 內容 cmp 對比本地內容（binary 比對）。
#       用於 9c 上傳失敗 → 使用者手動 Transmit 覆蓋後 → 9d 驗證。
#       印 match / mismatch / missing 並 exit 0。
#
#   card_helper.sh backup-pdf <pdf-path> <dest-dir>
#       備份簽呈 PDF 到 <dest-dir>，重命名為「簽呈編號-{表單號}.pdf」。
#       用 pypdf 改 mediabox/cropbox 隱藏「表單註釋」section 以下（含簽核列表）。
#       依賴 pypdf + pdfplumber（pip3 install --user pypdf pdfplumber）。
#
#   card_helper.sh extract-pdf <pdf-path>
#       從簽呈 PDF 機械萃取所有欄位，印 JSON 到 stdout。
#       設計給「Claude Read PDF + 腳本萃取」雙重檢核流程使用，
#       Claude 比對兩邊不一致 → 停下與使用者確認。
#       依賴 pdfplumber。
#
# basename 格式範例：20260527-王小明_Ming Wang
# dest-folder 格式範例：~/Documents/名片/SV/王小明_Ming Wang
# sidecar 路徑：/tmp/sv_card_fields.json

set -e

# 載入使用者環境變數（install.sh 會寫入此檔）
[ -f "$HOME/.config/sv-card/env" ] && . "$HOME/.config/sv-card/env"

# 可由環境變數或 ~/.config/sv-card/env 覆寫
SV_CARD_SKILL_DIR="${SV_CARD_SKILL_DIR:-$HOME/.claude/skills/sv-card}"
SV_TEMPLATE_DEFAULT="$SV_CARD_SKILL_DIR/templates/20260612-名片模版_TW 街聲.ai"
SV_TEMPLATE="${SV_TEMPLATE:-$SV_TEMPLATE_DEFAULT}"
SV_TEMPLATE_NO_MOBILE="${SV_TEMPLATE_NO_MOBILE:-$SV_CARD_SKILL_DIR/templates/20260622-名片模版_TW 街聲（無手機）.ai}"
SV_TEMPLATE_ZHONGZI="${SV_TEMPLATE_ZHONGZI:-$SV_CARD_SKILL_DIR/templates/20260612-名片模版_中子BVI.ai}"
# v0.24.0+：中子BVI 無手機版模板（簽呈無手機時自動選用，同 TW 街聲無手機版模式）
SV_TEMPLATE_ZHONGZI_NO_MOBILE="${SV_TEMPLATE_ZHONGZI_NO_MOBILE:-$SV_CARD_SKILL_DIR/templates/20260715-名片模版_中子BVI（無手機版）.ai}"
# v0.14.0+：SV_OUTPUT_BASE 改為「名片根目錄」（~/Documents/名片），各版型在其下接子資料夾。
#   - TW 街聲版 → $SV_OUTPUT_BASE/SV（SV 子夾只在真的做 TW 版時才建）
#   - 中子各版 → $SV_OUTPUT_BASE/{中子,中子文化,台灣中子}
# 首次製作確認的就是這個根目錄；不再預先建 SV 子夾。
SV_OUTPUT_BASE="${SV_OUTPUT_BASE:-$HOME/Documents/名片}"
# 中子版輸出 base（v0.10.1+，依簽呈「公司」欄位分流；v0.14.0+ 由根目錄衍生，改根目錄會一起跟著走）
SV_OUTPUT_BASE_ZHONGZI="${SV_OUTPUT_BASE_ZHONGZI:-$SV_OUTPUT_BASE/中子}"
SV_OUTPUT_BASE_ZHONGZI_WENHUA="${SV_OUTPUT_BASE_ZHONGZI_WENHUA:-$SV_OUTPUT_BASE/中子文化}"
# 台灣中子版（v0.12.0+，中子創新旗下台灣子公司；單一公司、無 --company 子分流）
SV_TEMPLATE_ZHONGZI_TAIWAN="${SV_TEMPLATE_ZHONGZI_TAIWAN:-$SV_CARD_SKILL_DIR/templates/20260612-名片模版_台灣中子.ai}"
# v0.24.0+：台灣中子無手機版模板（簽呈無手機時自動選用，同 TW 街聲無手機版模式）
SV_TEMPLATE_ZHONGZI_TAIWAN_NO_MOBILE="${SV_TEMPLATE_ZHONGZI_TAIWAN_NO_MOBILE:-$SV_CARD_SKILL_DIR/templates/20260715-名片模版_台灣中子（無手機版）.ai}"
SV_OUTPUT_BASE_ZHONGZI_TAIWAN="${SV_OUTPUT_BASE_ZHONGZI_TAIWAN:-$SV_OUTPUT_BASE/台灣中子}"
# 經典復刻款 BVI（v0.19.0+，半自動：自動填值，配色 + 收尾留人工）。雙面卡、專屬框集（含 _F/_B）。
# 輸出沿用中子分流（bvi→中子 / wenhua→中子文化 / taiwan→台灣中子）。
SV_TEMPLATE_CLASSIC="${SV_TEMPLATE_CLASSIC:-$SV_CARD_SKILL_DIR/templates/20260622-名片模版_經典復刻款.ai}"
SV_SIDECAR="${SV_SIDECAR:-/tmp/sv_card_fields.json}"

# 預設模板（TW 有手機版）防呆（v0.16.2）：env 覆寫成不存在的舊檔名時（例如換模板
# 檔名後 ~/.config/sv-card/env 仍寫死舊路徑），fallback 內建預設並警告，而非直接中止
# —— 否則連 extract-pdf 這類不需模板的子命令也會被擋。內建預設也找不到才報錯。
if [ ! -f "$SV_TEMPLATE" ]; then
    if [ -f "$SV_TEMPLATE_DEFAULT" ]; then
        echo "⚠️ SV_TEMPLATE 指向不存在的檔（$SV_TEMPLATE），改用內建預設：$SV_TEMPLATE_DEFAULT" >&2
        echo "   建議移除 ~/.config/sv-card/env 內寫死的 SV_TEMPLATE 行，改用內建預設免維護。" >&2
        SV_TEMPLATE="$SV_TEMPLATE_DEFAULT"
    else
        echo "ERROR: 找不到模板 .ai 檔（含內建預設）: $SV_TEMPLATE" >&2
        echo "  → 請執行 install.sh 重建 symlink" >&2
        exit 1
    fi
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
            # 中子系列跳過 artifacts（無 vCard / QR；v0.10.0+）
            # v0.12.0+：改判「非 tw 一律跳過」，涵蓋 zhongzi-bvi / zhongzi-taiwan 及未來新版型
            tt=$(python3 -c "import json,sys; print(json.load(open(sys.argv[1])).get('template_type','tw'))" "$SV_SIDECAR")
            if [ "$tt" != "tw" ]; then
                echo "📋 中子系列跳過 artifacts（無 vCard / QR）"
                exit 0
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
        title_en=""         # 英文職稱，僅經典款（classic-bvi）用；由簽呈職稱/其他需求欄萃取
        email=""
        mobile=""
        office_ext=""
        template_type="tw"  # tw（預設）/ zhongzi-bvi
        company=""          # 僅 template_type=zhongzi-bvi 時必填：bvi / wenhua（v0.10.1+）
        while [ $# -gt 0 ]; do
            case "$1" in
                --chinese)       chinese_full="$2"; shift 2 ;;
                --english)       english_name="$2"; shift 2 ;;
                --surname)       surname="$2"; shift 2 ;;
                --given)         given="$2"; shift 2 ;;
                --title)         title="$2"; shift 2 ;;
                --title-en)      title_en="$2"; shift 2 ;;
                --email)         email="$2"; shift 2 ;;
                --mobile)        mobile="$2"; shift 2 ;;
                --office-ext)    office_ext="$2"; shift 2 ;;
                --template-type) template_type="$2"; shift 2 ;;
                --company)       company="$2"; shift 2 ;;
                *)
                    echo "ERROR: init 不認識的參數: $1" >&2
                    exit 1 ;;
            esac
        done

        # template-type 驗證
        case "$template_type" in
            tw|zhongzi-bvi|zhongzi-taiwan|classic-bvi) ;;
            *)
                echo "ERROR: --template-type 只接受 'tw'、'zhongzi-bvi'、'zhongzi-taiwan' 或 'classic-bvi'，收到: $template_type" >&2
                exit 1 ;;
        esac

        # --company 驗證（v0.10.1+：中子版分流輸出路徑用；v0.19.0+ classic-bvi 加 taiwan）
        if [ "$template_type" = "zhongzi-bvi" ]; then
            case "$company" in
                bvi|wenhua) ;;
                "")
                    echo "ERROR: --template-type zhongzi-bvi 時必填 --company（bvi / wenhua）" >&2
                    echo "  → bvi    = 中子創新 BVI（母公司）" >&2
                    echo "  → wenhua = 中子文化股份有限公司（旗下公司）" >&2
                    exit 1 ;;
                *)
                    echo "ERROR: --company 只接受 'bvi' 或 'wenhua'，收到: $company" >&2
                    exit 1 ;;
            esac
        elif [ "$template_type" = "classic-bvi" ]; then
            case "$company" in
                bvi|wenhua|taiwan) ;;
                "")
                    echo "ERROR: --template-type classic-bvi 時必填 --company（bvi / wenhua / taiwan）" >&2
                    echo "  → bvi=中子創新 BVI / wenhua=中子文化 / taiwan=台灣中子創新" >&2
                    exit 1 ;;
                *)
                    echo "ERROR: --company 只接受 'bvi'、'wenhua' 或 'taiwan'，收到: $company" >&2
                    exit 1 ;;
            esac
        elif [ -n "$company" ]; then
            echo "ERROR: --company 僅在 --template-type zhongzi-bvi / classic-bvi 時可用" >&2
            exit 1
        fi

        # 經典款英文職稱必填（從簽呈職稱/其他需求欄萃取；缺則由 SKILL 流程停下問）
        if [ "$template_type" = "classic-bvi" ] && [ -z "$title_en" ]; then
            echo "ERROR: --template-type classic-bvi 時必填 --title-en（英文職稱）" >&2
            echo "  → 經典款有獨立英文職稱框 PH_TITLE_EN，請從簽呈職稱/其他需求欄取得" >&2
            exit 1
        fi

        # 必填檢查（mobile / office-ext 改為選填：空字串 = 簽呈沒填）
        missing=""
        for kv in "chinese:$chinese_full" "english:$english_name" "surname:$surname" \
                  "given:$given" "title:$title" "email:$email"; do
            k="${kv%%:*}"; v="${kv#*:}"
            [ -z "$v" ] && missing="$missing --$k"
        done
        if [ -n "$missing" ]; then
            echo "ERROR: init 缺少必填參數:$missing" >&2
            echo "用法: init --chinese ... --english ... --surname ... --given ..." >&2
            echo "          --title ... --email ... [--mobile ...] [--office-ext ...]" >&2
            echo "          [--template-type tw|zhongzi-bvi]" >&2
            echo "  --mobile 空（或不傳）→ 用無手機版模板，vCard 跳過 TEL CELL 行" >&2
            echo "  --office-ext 空（或不傳）→ 新版分機框 PH_PHONE_EXT 留空（公司電話靜態於模板）" >&2
            echo "  --template-type 預設 'tw'，中子版傳 'zhongzi-bvi'（跳過 vCard / QR）" >&2
            exit 1
        fi

        # legacy_office：1 = 舊無手機版 template（仍用合成框 PH_PHONE_OFFICE）；
        #                0 = 新版 template（公司電話靜態於 template，只填分機框 PH_PHONE_EXT）
        # v0.15.x：公司電話改固定靜態，分機獨立框（對照 PDF 室內分機，留白則框留白）。
        #          v0.18.0：無手機版已更新為新排版（20260622），改 PH_PHONE_EXT 框，legacy 分支不再用於無手機版。
        legacy_office=0
        # 選模板（v0.10.0+ 加中子版分支；v0.12.0+ 加台灣中子分支）
        if [ "$template_type" = "zhongzi-bvi" ]; then
            if [ -z "$mobile" ]; then
                # v0.24.0+：中子BVI 無手機版模板（同 TW 街聲無手機版模式，簽呈無手機自動選用）
                template="$SV_TEMPLATE_ZHONGZI_NO_MOBILE"
                if [ ! -f "$template" ]; then
                    echo "ERROR: 找不到中子BVI無手機版模板: $template" >&2
                    echo "  → 請設定 SV_TEMPLATE_ZHONGZI_NO_MOBILE 環境變數，或執行 install.sh 後重試" >&2
                    exit 1
                fi
                echo "📋 使用中子BVI無手機版模板（無 vCard / QR 流程；簽呈沒填手機）"
            else
                template="$SV_TEMPLATE_ZHONGZI"
                if [ ! -f "$template" ]; then
                    echo "ERROR: 找不到中子版模板: $template" >&2
                    echo "  → 請設定 SV_TEMPLATE_ZHONGZI 環境變數，或執行 install.sh 後重試" >&2
                    exit 1
                fi
                echo "📋 使用中子版模板（無 vCard / QR 流程）"
            fi
        elif [ "$template_type" = "zhongzi-taiwan" ]; then
            if [ -z "$mobile" ]; then
                # v0.24.0+：台灣中子無手機版模板（同 TW 街聲無手機版模式，簽呈無手機自動選用）
                template="$SV_TEMPLATE_ZHONGZI_TAIWAN_NO_MOBILE"
                if [ ! -f "$template" ]; then
                    echo "ERROR: 找不到台灣中子無手機版模板: $template" >&2
                    echo "  → 請設定 SV_TEMPLATE_ZHONGZI_TAIWAN_NO_MOBILE 環境變數，或執行 install.sh 後重試" >&2
                    exit 1
                fi
                echo "📋 使用台灣中子無手機版模板（無 vCard / QR 流程；公司名靜態於模板；簽呈沒填手機）"
            else
                template="$SV_TEMPLATE_ZHONGZI_TAIWAN"
                if [ ! -f "$template" ]; then
                    echo "ERROR: 找不到台灣中子版模板: $template" >&2
                    echo "  → 請設定 SV_TEMPLATE_ZHONGZI_TAIWAN 環境變數，或執行 install.sh 後重試" >&2
                    exit 1
                fi
                echo "📋 使用台灣中子版模板（無 vCard / QR 流程；公司名靜態於模板）"
            fi
        elif [ "$template_type" = "classic-bvi" ]; then
            # 經典復刻款 BVI（v0.19.0+，半自動）：雙面卡、專屬框集，無 vCard / QR
            template="$SV_TEMPLATE_CLASSIC"
            if [ ! -f "$template" ]; then
                echo "ERROR: 找不到經典復刻款模板: $template" >&2
                echo "  → 請設定 SV_TEMPLATE_CLASSIC 環境變數，或執行 install.sh 後重試" >&2
                exit 1
            fi
            echo "📋 使用經典復刻款模板（半自動：自動填值 → 停下手動配色 → 人工收尾）"
            if [ -z "$mobile" ]; then
                echo "⚠️ 經典款雙面皆有手機框，但簽呈無手機 → PH_PHONE_MOBILE_F/_B 會留樣本值，請手動處理。" >&2
            fi
        elif [ -z "$mobile" ]; then
            # TW 無手機版
            template="$SV_TEMPLATE_NO_MOBILE"
            if [ ! -f "$template" ]; then
                echo "ERROR: 找不到無手機版模板: $template" >&2
                echo "  → 請設定 SV_TEMPLATE_NO_MOBILE 環境變數，或執行 install.sh 後重試" >&2
                exit 1
            fi
            echo "📋 使用無手機版模板（簽呈沒填手機）"
            # v0.18.0：無手機版已改新排版（20260622），用新分機框 PH_PHONE_EXT，與有手機版一致（legacy_office 維持 0）
        else
            # TW 有手機版（預設，新版）
            template="$SV_TEMPLATE"
        fi

        name_folder="${chinese_full}_${english_name}"
        # 選輸出 base
        #   - 台灣中子版（v0.12.0+）：無 --company，依 template_type 直接分流
        #   - 中子 BVI 版（v0.10.1+）：依 --company 分流
        #   - 其餘：TW 版預設
        if [ "$template_type" = "zhongzi-taiwan" ]; then
            output_base="$SV_OUTPUT_BASE_ZHONGZI_TAIWAN"
        else
            case "$company" in
                bvi)    output_base="$SV_OUTPUT_BASE_ZHONGZI" ;;
                wenhua) output_base="$SV_OUTPUT_BASE_ZHONGZI_WENHUA" ;;
                taiwan) output_base="$SV_OUTPUT_BASE_ZHONGZI_TAIWAN" ;;  # 經典款 --company taiwan（v0.19.0+）
                *)      output_base="$SV_OUTPUT_BASE/SV" ;;  # TW 版：根目錄下 SV 子夾（v0.14.0+）
            esac
        fi
        dest_dir="$output_base/$name_folder"
        today=$(date +%Y%m%d)
        new_file="$dest_dir/${today}-${name_folder}.ai"

        mkdir -p "$dest_dir"
        cp -L "$template" "$new_file"
        echo "✅ 模板已複製: $new_file"

        # 寫 sidecar JSON
        # 處理規則：
        #   - 新版三 template（legacy_office=0）：公司電話靜態於 template，只填分機框
        #     PH_PHONE_EXT = "#" + 分機（office_ext 空 → 寫空字串 ""，清掉模板範例 #375）
        #   - 舊無手機版（legacy_office=1）：沿用合成框 PH_PHONE_OFFICE（office_ext 空 → 純電話號）
        #   - mobile 空 → fields 不放 PH_PHONE_MOBILE（replace_fields.jsx 找不到會 silent skip）
        #                 artifacts 也不放 mobile（make_vcard.py 會跳過 TEL CELL 行）
        SURNAME="$surname" GIVEN="$given" EN="$english_name" \
        TITLE="$title" EMAIL="$email" MOBILE="$mobile" \
        OFFICE_EXT="$office_ext" DEST_DIR="$dest_dir" \
        DEST_PATH="$new_file" LEGACY_OFFICE="$legacy_office" \
        TEMPLATE_TYPE="$template_type" COMPANY="$company" TITLE_EN="$title_en" \
        SV_CARD_SCRIPT_DIR="$SV_CARD_SKILL_DIR/scripts" \
        python3 - <<'PYEOF' > "$SV_SIDECAR"
import json, os, sys
sys.path.insert(0, os.environ["SV_CARD_SCRIPT_DIR"])
from company_config import phone

mobile_vcard   = os.environ["MOBILE"]
# 分機統一去掉開頭的 #（簽呈填法不一致：有人填 402、有人填 #321；v0.16.1）
# 新版分機框 PH_PHONE_EXT = "#" + ext，若 ext 已含 # 會變 ##321，故先 strip
office_ext     = os.environ["OFFICE_EXT"].strip().lstrip("#")
en             = os.environ["EN"]
template_type  = os.environ["TEMPLATE_TYPE"]
company        = os.environ["COMPANY"]
dest_path      = os.environ["DEST_PATH"]  # v0.10.3+：jsx 用此繞 corrupt fullName
# vcf 檔名一律只取英文（v0.19.x）：英文名欄位可能中英混填（例「王小美」），
# .vcf 檔名 + 上傳 URL + QR 只用 ASCII 英文部分（→ Owner.vcf），中文絕不進檔名。
# 卡片顯示 PH_NAME_EN 仍用完整 en（保留使用者填的中英混合，兩者互不影響）。
# 若英文名完全沒有 ASCII（純中文）→ fallback 回原 en，交由 SOP「非常規簽呈」停下問。
import re as _re_vcf
_en_ascii = _re_vcf.sub(r"[^\x00-\x7F]", "", en).strip()
vcf_name       = (_en_ascii if _en_ascii else en).replace(" ", "") + ".vcf"

legacy_office = os.environ.get("LEGACY_OFFICE") == "1"

def to_card_mobile(s):
    # 名片用 +886 國碼格式（v0.19.x）：標準台灣手機（10 碼 09XXXXXXXX，不論簽呈填法有無
    # 空格/dash）一律輸出 +886-9XX-XXX-XXX（3-3-3），例 0909050269 → +886-912-324-850。
    # 修正舊版只拆末 6 碼、簽呈手機無空格時中間組沒切開（→ +886-912324-850）的問題。
    import re as _re
    digits = _re.sub(r"\D", "", s)
    if digits.startswith("886"):
        digits = "0" + digits[3:]
    if len(digits) == 10 and digits.startswith("09"):
        return "+886-" + digits[1:4] + "-" + digits[4:7] + "-" + digits[7:]
    # 非標準號碼（長度/開頭不符）：沿用舊邏輯「空格→dash、開頭0→+886-、末6碼拆3+3」
    s = s.replace(" ", "-")
    if s.startswith("0"):
        s = "+886-" + s[1:]
    s = _re.sub(r"(\d{3})(\d{3})$", r"\1-\2", s)
    return s

def format_mobile_local(s):
    # 本地分組格式 09XX-XXX-XXX（例 0909-050269 → 0909-050-269）；
    # 帶 886 國碼先還原本地 0 開頭；非台灣手機（長度/開頭不符）保留原字串
    import re as _re
    d = _re.sub(r"\D", "", s)
    if d.startswith("886"):
        d = "0" + d[3:]
    if len(d) == 10 and d.startswith("09"):
        return d[:4] + "-" + d[4:7] + "-" + d[7:]
    return s.strip()

if template_type == "classic-bvi":
    # 經典復刻款 BVI（v0.19.0+）：雙面卡專屬框集（含 _F/_B），公司中英依 --company 分支。
    # 配色 / 收尾留人工；此處只組「填值」欄位。
    CLASSIC_CO = {
        "bvi":    ("中子創新有限公司",        "Neutron Innovation (BVI) Ltd."),
        "wenhua": ("中子文化股份有限公司",     "Neutron Culture Co., Ltd."),
        "taiwan": ("台灣中子創新股份有限公司",  "Neutron Innovation (Taiwan) Ltd."),
    }
    co_cn, co_en = CLASSIC_CO[company]
    fields = {
        "PH_NAME_CN":      os.environ["SURNAME"] + os.environ["GIVEN"],
        "PH_NAME_EN":      en,
        "PH_TITLE":        os.environ["TITLE"],
        "PH_TITLE_EN":     os.environ.get("TITLE_EN", ""),
        "PH_EMAIL":        os.environ["EMAIL"],
        # 分機格式 ext.NNN（經典款專屬；其他款是 #NNN）；無分機 → 空字串清掉樣本
        "PH_PHONE_EXT":    ("ext." + office_ext) if office_ext else "",
        "PH_COMPANY":      co_cn,
        "PH_COMPANY_EN_F": co_en,
        "PH_COMPANY_EN_B": co_en,
    }
    if mobile_vcard:
        # 正面純號碼本地分組；背面「Mobile: +886-…」
        fields["PH_PHONE_MOBILE_F"] = format_mobile_local(mobile_vcard)
        fields["PH_PHONE_MOBILE_B"] = "Mobile: " + to_card_mobile(mobile_vcard)
else:
    fields = {
        "PH_NAME_CN_SURNAME": os.environ["SURNAME"],
        "PH_NAME_CN_GIVEN":   os.environ["GIVEN"],
        "PH_NAME_EN":         en,
        "PH_TITLE":           os.environ["TITLE"],
        "PH_EMAIL":           os.environ["EMAIL"],
    }

    # 公司電話 / 分機（v0.15.x 改：公司電話固定靜態於 template，分機獨立框）
    if legacy_office:
        # 舊無手機版 template：合成框 PH_PHONE_OFFICE（公司電話 + 分機；無分機則純號碼）
        ph_phone_office = phone()["office"]
        if office_ext:
            ph_phone_office += "#" + office_ext
        fields["PH_PHONE_OFFICE"] = ph_phone_office
    else:
        # 新版 template：公司電話靜態於 template，只填分機框（對照 PDF 室內分機）
        # 有分機 → "#" + 分機（例 #375）；留白 → 寫空字串清掉模板範例值（不可不寫，否則殘留 #375）
        fields["PH_PHONE_EXT"] = ("#" + office_ext) if office_ext else ""

    if mobile_vcard:
        fields["PH_PHONE_MOBILE"] = to_card_mobile(mobile_vcard)

    # 中子版動態公司名（v0.10.2+）：PH_COMPANY 依 --company 推導
    COMPANY_NAME_MAP = {
        "bvi":    "中子創新有限公司",
        "wenhua": "中子文化股份有限公司",
    }
    if template_type == "zhongzi-bvi" and company in COMPANY_NAME_MAP:
        fields["PH_COMPANY"] = COMPANY_NAME_MAP[company]

# template_type 標記在 sidecar top level，artifacts 子命令會據此 skip vCard/QR（v0.10.0+ 中子版）
# company 標記在 sidecar top level（v0.10.1+：中子版分流輸出路徑）
# dest_path 在 sidecar top level（v0.10.3+：jsx 用此繞 corrupt fullName 做顯式 saveAs）
out = {"fields": fields, "template_type": template_type, "dest_path": dest_path}
if company:
    out["company"] = company

if template_type == "tw":
    # 只 TW 版需要 artifacts 區塊（產 vCard + QR）
    artifacts = {
        "surname":  os.environ["SURNAME"],
        "given":    os.environ["GIVEN"],
        "en":       en,
        "title":    os.environ["TITLE"],
        "email":    os.environ["EMAIL"],
        "folder":   os.environ["DEST_DIR"],
        "vcf_name": vcf_name,
    }
    if mobile_vcard:
        artifacts["mobile"] = mobile_vcard
    out["artifacts"] = artifacts

print(json.dumps(out, ensure_ascii=False, indent=2))
PYEOF
        echo "✅ sidecar 寫入: $SV_SIDECAR"

        if pgrep -x "Adobe Illustrator" > /dev/null; then
            echo "⚠️ Illustrator 已在運行，open 可能被歡迎頁攔截。建議冷啟動。"
        fi

        target_doc="${today}-${name_folder}.ai"
        open -a "Adobe Illustrator" "$new_file"
        echo "✅ open 已發送，輪詢 doc 就緒中（目標：$target_doc）..."

        # v0.16.1+：必須「current document == 目標檔」才算就緒，不再「有 doc 就當成功」。
        # Illustrator 已運行時 open 常被既有文件攔截（current document 會是使用者開著的
        # 別的檔），若直接往下替換會改錯文件。偵測到「有 doc 但非目標」持續數秒即判定
        # 攔截（背景 throttle 下 open -a / osascript open 都不會自己切 current，實測無效，
        # 只有 MCP app.open 會 bringToFront 可靠生效），不傻等滿 60 秒；改印 NEEDS_MCP_OPEN=1
        # 交由流程（SKILL Step 1→2 之間）用 MCP app.open 強制開啟目標檔再繼續。
        name=""
        mismatch=0
        for i in $(seq 1 60); do
            sleep 1
            name=$(osascript -e 'tell application "Adobe Illustrator" to if (count of documents) > 0 then return name of current document' 2>/dev/null || echo "")
            if [ "$name" = "$target_doc" ]; then
                echo "✅ ${i}s: doc=$name"
                echo "BASENAME=${today}-${name_folder}"
                echo "DEST_DIR=$dest_dir"
                exit 0
            fi
            [ -n "$name" ] && mismatch=$((mismatch + 1))
            [ "$mismatch" -ge 4 ] && break
        done

        # 未切到目標檔（攔截或未就緒）— 檔案已建好，交由流程用 MCP app.open 修復
        echo "⚠️ open 未就緒：current document=「${name:-（無）}」≠ 目標「$target_doc」" >&2
        echo "   （Illustrator 已運行時 open 易被既有文件攔截）需用 MCP app.open 強制開啟目標檔：" >&2
        echo "   $new_file" >&2
        echo "BASENAME=${today}-${name_folder}"
        echo "DEST_DIR=$dest_dir"
        echo "NEEDS_MCP_OPEN=1"
        exit 0
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
        # 支援 --check-only：只做「拿密碼 + preflight + 查 server」，不上傳
        # 結果印 exists / new 並 exit 0，供 SKILL.md Step 9a 預檢判斷
        check_only=0
        vcf=""
        while [ $# -gt 0 ]; do
            case "$1" in
                --check-only) check_only=1; shift ;;
                *)            vcf="$1"; shift ;;
            esac
        done
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

        # ---- 密碼 dialog（首次 / 重輸共用）----
        prompt_password() {
            local title="$1"
            local prompt_text="$2"
            osascript <<APPLESCRIPT 2>/dev/null || true
try
    set p to text returned of (display dialog "${prompt_text}

host: ${host}
user: ${user}

密碼會存到 macOS Keychain，下次不再詢問。" with title "${title}" default answer "" with hidden answer)
    return p
on error
    return ""
end try
APPLESCRIPT
        }

        # ---- preflight 測登入（curl noop list）----
        # 0 = OK；67 = auth 失敗（密碼錯）；其他 = 連線/server 問題
        preflight_login() {
            curl -sS -fS --connect-timeout 10 --user "${user}:${password}" \
                 --list-only "ftp://${host}${remote_dir}/" > /dev/null 2>&1
        }

        # 第一階段：拿密碼（Keychain 有就用，沒有就跳 dialog）
        password=$(security find-internet-password -s "$host" -a "$user" -l "$kc_label" -w 2>/dev/null || true)
        if [ -z "$password" ]; then
            echo "🔐 首次上傳，請在 dialog 輸入密碼"
            password=$(prompt_password "sv-card 首次上傳設定" "請輸入 Transmit favorite「${fav_name}」的 FTP 密碼")
            if [ -z "$password" ]; then
                echo "❌ 使用者取消輸入密碼" >&2
                exit 1
            fi
            security add-internet-password -s "$host" -a "$user" -l "$kc_label" -w "$password" -U
            echo "✅ 密碼已存入 macOS Keychain（label：${kc_label}）"
        fi

        # 第二階段：preflight 驗證登入；失敗則引導重輸密碼一次
        echo "🔍 檢查登入狀態..."
        if ! preflight_login; then
            preflight_exit=$?
            echo "🔐 登入失敗（curl exit ${preflight_exit}），可能密碼錯誤或已變更。請重新輸入。"
            security delete-internet-password -s "$host" -a "$user" -l "$kc_label" 2>/dev/null || true
            password=$(prompt_password "sv-card 重新登入" "登入失敗，請重新輸入 Transmit favorite「${fav_name}」的 FTP 密碼")
            if [ -z "$password" ]; then
                echo "❌ 使用者取消輸入密碼" >&2
                exit 1
            fi
            security add-internet-password -s "$host" -a "$user" -l "$kc_label" -w "$password" -U
            if ! preflight_login; then
                preflight_exit=$?
                echo "❌ 登入仍失敗（curl exit ${preflight_exit}）" >&2
                echo "  → 可能原因：密碼錯誤、帳號未開通 ${remote_dir}/ 寫權限、或網路問題" >&2
                echo "  → 請截圖 slack 洽產品工程部協助確認帳號權限" >&2
                exit 1
            fi
        fi
        echo "✅ 登入 ${host} 成功"

        vcf_basename=$(basename "$vcf")

        # 上傳前先查 server 是否已有同名檔（區分「新上傳」vs「覆蓋舊檔」）
        existed_before=0
        if curl -sS --list-only "ftp://${host}${remote_dir}/" --user "${user}:${password}" 2>/dev/null \
               | grep -qFx "$vcf_basename"; then
            existed_before=1
        fi

        # --check-only 模式：只回報「server 上是否已有同名檔」，不上傳
        if [ "$check_only" = "1" ]; then
            if [ "$existed_before" = "1" ]; then
                echo "exists"
            else
                echo "new"
            fi
            exit 0
        fi

        # STOR + retry（ProFTPD 偶有 transient 550，retry 一次幾乎都會 work）
        # 注意：不要 DELE-then-STOR。實測：對「owner 非自己」的檔有 STOR 覆寫權限，
        # 但沒有 DELE 權限 — 跑 DELE 反而會 fail。直接 STOR 是對的路徑。
        upload_attempt() {
            curl -sS -fS --ftp-create-dirs \
                 --upload-file "$vcf" \
                 "ftp://${host}${remote_dir}/${vcf_basename}" \
                 --user "${user}:${password}"
        }

        echo "📤 curl 上傳：$vcf_basename"
        success=0
        if upload_attempt; then
            success=1
        else
            curl_exit=$?
            echo "  ⚠️ 第一次 STOR 失敗（curl exit ${curl_exit}）— 1 秒後 retry..."
            sleep 1
            if upload_attempt; then
                success=1
                echo "  ✅ retry 成功"
            else
                curl_exit=$?
            fi
        fi

        if [ "$success" = "1" ]; then
            if [ "$existed_before" = "1" ]; then
                echo "✅ vCard 已上傳 server 並覆蓋舊檔"
            else
                echo "✅ vCard 已上傳 server"
            fi
            echo "📋 公開 URL：http://${host}${remote_dir}/${vcf_basename}"
        else
            echo "❌ STOR 兩次都失敗（curl exit ${curl_exit}），登入已驗證 OK" >&2
            echo "  → 對應檔案：${vcf_basename}" >&2
            echo "  → 本地 vcf 路徑：${vcf}" >&2
            echo "  → 請手動用 Transmit 上傳並覆蓋舊檔" >&2
            exit 1
        fi
        ;;

    verify-vcard)
        # 驗證 server 上 vcf 內容 = 本地 vcf 內容（用於使用者手動上傳後的確認）
        # 印 match / mismatch / missing，exit 0
        vcf="$1"
        if [ -z "$vcf" ] || [ ! -f "$vcf" ]; then
            echo "ERROR: verify-vcard 需要 <vcf-path>（檔案需存在）" >&2
            exit 1
        fi

        fav_name="${SV_TRANSMIT_FAVORITE:-Streetvoice}"
        remote_dir="${SV_TRANSMIT_REMOTE_DIR:-/vcard}"
        kc_label="sv-card upload (${fav_name})"

        host=$(osascript -e "tell application \"Transmit\" to return address of (first favorite whose name is \"${fav_name}\")" 2>/dev/null || true)
        user=$(osascript -e "tell application \"Transmit\" to return user name of (first favorite whose name is \"${fav_name}\")" 2>/dev/null || true)
        if [ -z "$host" ] || [ -z "$user" ]; then
            echo "ERROR: 找不到 Transmit favorite \"${fav_name}\"" >&2
            exit 1
        fi

        password=$(security find-internet-password -s "$host" -a "$user" -l "$kc_label" -w 2>/dev/null || true)
        if [ -z "$password" ]; then
            echo "ERROR: Keychain 沒有 ${fav_name} 的密碼（需先跑過 upload-vcard 至少一次）" >&2
            exit 1
        fi

        vcf_basename=$(basename "$vcf")
        remote_tmp="/tmp/sv_verify_${vcf_basename}"

        # 抓 server 內容
        if ! curl -sS -fS --connect-timeout 10 \
                "ftp://${host}${remote_dir}/${vcf_basename}" \
                --user "${user}:${password}" -o "$remote_tmp" 2>/dev/null; then
            rm -f "$remote_tmp"
            echo "missing"
            exit 0
        fi

        # 用 cmp 比對 binary
        if cmp -s "$vcf" "$remote_tmp"; then
            rm -f "$remote_tmp"
            echo "match"
        else
            rm -f "$remote_tmp"
            echo "mismatch"
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

    finalize-classic)
        # 經典款專屬收尾（v0.19.0+）：原檔 + PNG-24（2000×668）+ OL。
        # 用於「手動配色完成後」的人工收尾（配合 finalize.jsx 已產出 /tmp/output_*.ai）。
        # PNG-24：sips 出 PNG（含 alpha）→ PIL 合底色轉 24-bit RGB。
        #   bg=white → 改色版（已改底色，用白底）；bg=grey → 無改色版（灰底 K70 襯白卡）
        # 用法：finalize-classic <dest-folder> <basename> [white|grey]
        dest="$1"
        basename="$2"
        bg="${3:-grey}"
        if [ -z "$dest" ] || [ -z "$basename" ]; then
            echo "ERROR: finalize-classic 需要 <dest-folder> <basename> [white|grey]" >&2
            exit 1
        fi
        case "$bg" in white|grey) ;; *)
            echo "ERROR: finalize-classic 第三參數只接受 white / grey，收到: $bg" >&2
            exit 1 ;;
        esac

        # 搬原檔
        mv /tmp/output_original.ai "$dest/${basename}.ai"
        # 出 PNG-24（雙面 3:1，2000×668）
        cp "$dest/${basename}.ai" /tmp/temp_classic.pdf
        sips -s format png --resampleHeightWidth 668 2000 /tmp/temp_classic.pdf --out /tmp/classic_raw.png > /dev/null
        SV_CLASSIC_BG="$bg" python3 - "$dest/${basename}.png" <<'PYPNG'
import sys, os
from PIL import Image
bg = os.environ.get("SV_CLASSIC_BG", "grey")
color = (255, 255, 255) if bg == "white" else (76, 76, 76)  # 改色→白底；無改色→灰底 K70(≈76,76,76)
img = Image.open("/tmp/classic_raw.png").convert("RGBA")
canvas = Image.new("RGB", img.size, color)  # RGB 無 alpha = 嚴格 PNG-24
canvas.paste(img, mask=img.split()[3])      # 用 alpha 當遮罩貼上，去掉透明
canvas.save(sys.argv[1])
print(f"✅ PNG-24（{bg} 底，{canvas.size[0]}x{canvas.size[1]}）→ {sys.argv[1]}")
PYPNG
        rm -f /tmp/temp_classic.pdf /tmp/classic_raw.png

        # 搬 OL
        mv /tmp/output_ol.ai "$dest/OL-${basename}.ai"
        echo "✅ OL → $dest/OL-${basename}.ai"
        echo
        echo "📁 最終產出（經典款 4 檔：原檔 / OL / PNG-24 / 簽呈 PDF）："
        ls -la "$dest/"
        ;;

    backup-pdf)
        # 備份簽呈 PDF 到 DEST_DIR，重命名為「簽呈編號-{表單號}.pdf」
        # v0.10.3+：固定保留上方 352px（取代 pdfplumber 找「表單註釋」word top 的動態邏輯）
        # 表單號取得：CLI 第三參數 > pdfplumber regex「表單號:」> 報錯
        pdf="$1"
        dest="$2"
        form_no="$3"  # 選填；中子 PDF 必傳
        if [ -z "$pdf" ] || [ -z "$dest" ]; then
            echo "ERROR: backup-pdf 需要 <pdf-path> <dest-dir> [<form-no>]" >&2
            echo "  <form-no> 選填：中子 PDF 表單號圖片化抓不到，必傳；TW 自動 regex 抓" >&2
            exit 1
        fi
        if [ -n "$form_no" ]; then
            exec python3 "$SV_CARD_SKILL_DIR/scripts/backup_signoff_pdf.py" \
                "$pdf" "$dest" --form-no "$form_no"
        else
            exec python3 "$SV_CARD_SKILL_DIR/scripts/backup_signoff_pdf.py" "$pdf" "$dest"
        fi
        ;;

    extract-pdf)
        # 從簽呈 PDF 機械萃取所有欄位，印 JSON 到 stdout
        # 配合 Claude Read PDF 雙重檢核：腳本抓欄位、Claude 看視覺校 typo / 特殊備註
        pdf="$1"
        if [ -z "$pdf" ]; then
            echo "ERROR: extract-pdf 需要 <pdf-path>" >&2
            exit 1
        fi
        exec python3 "$SV_CARD_SKILL_DIR/scripts/extract_signoff_fields.py" "$pdf"
        ;;

    *)
        echo "Usage:" >&2
        echo "  $0 check-firstrun" >&2
        echo "  $0 confirm-firstrun <output-path>" >&2
        echo "  $0 init --chinese ... --english ... --surname ... --given ..." >&2
        echo "              --title ... --email ... [--mobile ...] [--office-ext ...]" >&2
        echo "  $0 artifacts [args...]" >&2
        echo "  $0 backup-pdf <pdf-path> <dest-dir>" >&2
        echo "  $0 extract-pdf <pdf-path>" >&2
        echo "  $0 save-original <dest-folder> <basename>" >&2
        echo "  $0 save-ol <dest-folder> <basename>" >&2
        echo "  $0 finalize <dest-folder> <basename>" >&2
        echo "  $0 upload-vcard [--check-only] <vcf-path>" >&2
        echo "  $0 verify-vcard <vcf-path>" >&2
        exit 1
        ;;
esac
