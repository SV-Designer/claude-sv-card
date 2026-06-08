#!/usr/bin/env python3
"""
SV 名片產生流程的「資料層」：vCard + QR Code SVG + 預處理 SVG

由 Claude Code 在 SV_名片自動化製作 SOP 中呼叫,兩種模式：

  A. sidecar 模式（推薦,由 card_helper.sh init 寫入）：
       python3 make_card_artifacts.py --from /tmp/sv_card_fields.json
     讀 JSON 的 artifacts 區塊:{ surname, given, en, title, email,
                                 mobile, folder, vcf_name }

  B. 命名參數模式（向後相容）：
       python3 make_card_artifacts.py \\
           --surname "王" --given "小明" --en "Ming Wang" \\
           --title "美術設計" --email "..." --mobile "+886 900 000 000" \\
           --folder "..." --vcf-name "MingWang.vcf"

執行內容（只做這三件事,不會碰其他位置）：
  1. 在 {folder} 內產生 {vcf-name}（呼叫 make_vcard.make_vcard）
  2. 在 {folder} 內產生 "QR Code.svg"（make_qr.make_qr,
     URL = http://drive.streetvoice.com/vcard/{vcf-name}）
  3. 預處理「QR Code.svg」剝 id="bg" 背景白底 → 寫到 /tmp/qr_processed.svg
     供 place_qr.jsx 在 Illustrator 中匯入

不會做:開檔、改 Illustrator、覆寫資料夾外檔案、發送網路請求。
"""

import argparse
import json
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from make_vcard import make_vcard
from make_qr import make_qr
from company_config import vcard_config


def main():
    p = argparse.ArgumentParser(
        description="Generate vCard + QR SVG + preprocess for SV business card",
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    p.add_argument("--from", dest="from_path", type=Path,
                   help="從 sidecar JSON 讀 artifacts 區塊（推薦）")
    p.add_argument("--surname", help="中文姓,例如「王」")
    p.add_argument("--given", help="中文名,例如「小明」")
    p.add_argument("--en", help="英文名(含 alias),例如「Ming Wang」或「阿明 Ming Wang」")
    p.add_argument("--title", help="職稱")
    p.add_argument("--email")
    p.add_argument("--mobile", help="沿用簽呈原格式,例如「+886 900 000 000」或「0900-000-000」")
    p.add_argument("--folder", type=Path, help="輸出資料夾(必須已存在)")
    p.add_argument("--vcf-name", help="vCard 檔名,例如「MingWang.vcf」(無空格英文名 + .vcf)")
    args = p.parse_args()

    if args.from_path:
        if not args.from_path.is_file():
            sys.exit(f"ERROR: sidecar 不存在: {args.from_path}")
        sidecar = json.loads(args.from_path.read_text(encoding="utf-8"))
        a = sidecar.get("artifacts")
        if not a:
            sys.exit(f"ERROR: sidecar 缺 'artifacts' 區塊: {args.from_path}")
        surname  = a["surname"]
        given    = a["given"]
        en       = a["en"]
        title    = a["title"]
        email    = a["email"]
        mobile   = a.get("mobile", "")  # 可選：簽呈沒填手機時 omit，vCard 跳過 TEL CELL
        folder   = Path(a["folder"])
        vcf_name = a["vcf_name"]
    else:
        # 命名參數模式（向後相容）— mobile 改為選填
        required = ("surname", "given", "en", "title", "email",
                    "folder", "vcf_name")
        missing = [k for k in required if getattr(args, k, None) is None]
        if missing:
            sys.exit("ERROR: 命名參數模式需提供: "
                     + ", ".join("--" + m.replace("_", "-") for m in missing))
        surname  = args.surname
        given    = args.given
        en       = args.en
        title    = args.title
        email    = args.email
        mobile   = args.mobile or ""  # 選填
        folder   = args.folder
        vcf_name = args.vcf_name

    if not folder.is_dir():
        sys.exit(f"ERROR: 資料夾不存在或不是目錄: {folder}")

    data = {
        "chinese_surname": surname,
        "chinese_given": given,
        "english_name": en,
        "title": title,
        "email": email,
        "mobile": mobile,
    }

    # 1. vCard
    vcf_path = folder / vcf_name
    make_vcard(data, vcf_path)

    # 2. QR Code SVG
    qr_path = folder / "QR Code.svg"
    qr_url = f"{vcard_config()['url_base']}{vcf_name}"
    make_qr(qr_url, qr_path)

    # 3. 預處理 SVG（剝 id="bg" 背景白底）→ /tmp
    svg = qr_path.read_text(encoding="utf-8")
    svg = re.sub(r'<rect id="bg"[^/>]*/>', "", svg)
    Path("/tmp/qr_processed.svg").write_text(svg, encoding="utf-8")
    print("✅ 預處理 SVG → /tmp/qr_processed.svg")


if __name__ == "__main__":
    main()
