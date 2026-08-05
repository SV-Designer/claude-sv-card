#!/usr/bin/env python3
"""
StreetVoice 名片 vCard 產生器

用法:
    python3 make_vcard.py
    (資料目前 hardcoded 在 main 區，未來可改成讀 JSON)

設計概念:
    - 從一個「樣板 vCard」抽取共用欄位（公司 logo PHOTO、FAX、地址、ORG、URL）
    - 套上個人化資料產生新 .vcf
"""
import os
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from company_config import load as load_company_config

# === 樣板 vCard：含公司 logo PHOTO 區塊（僅在 include_photo=True 時讀取）===
# 預設 None 代表不嵌 PHOTO（macOS 通訊錄會自動依姓氏產字母頭貼，這是建議行為）。
# 若要嵌入自訂 PHOTO，請設環境變數 SV_VCARD_TEMPLATE 指向樣板 .vcf
TEMPLATE_VCF = Path(os.environ["SV_VCARD_TEMPLATE"]).expanduser() if os.environ.get("SV_VCARD_TEMPLATE") else None


def extract_photo_block(template_path: Path) -> str:
    """從樣板 vCard 抽出 PHOTO;ENCODING=b;TYPE=JPEG:... 整段（含後續折行）"""
    text = template_path.read_text(encoding="utf-8")
    lines = text.splitlines()
    photo_lines = []
    in_photo = False
    for line in lines:
        if line.startswith("PHOTO;"):
            in_photo = True
            photo_lines.append(line)
        elif in_photo:
            # vCard 折行：以空白開頭表示同一欄位的續行
            if line.startswith(" ") or line.startswith("\t"):
                photo_lines.append(line)
            else:
                break  # PHOTO 結束
    return "\r\n".join(photo_lines)


def format_mobile_local(s: str) -> str:
    """vCard CELL 用本地分組格式：09XX-XXX-XXX（4-3-3），例 0909-050269 → 0909-050-269。

    - 先取純數字；若帶國碼 886 先還原成本地 0 開頭
    - 台灣手機 10 碼（09 開頭）→ 4-3-3 分組
    - 其他長度 / 非台灣手機 → 保留原字串（去頭尾空白），不強套格式
    """
    digits = re.sub(r"\D", "", s)
    if digits.startswith("886"):
        digits = "0" + digits[3:]
    if len(digits) == 10 and digits.startswith("09"):
        return f"{digits[:4]}-{digits[4:7]}-{digits[7:]}"
    return s.strip()


def build_vcard(data: dict, photo_block: str = "") -> str:
    """根據個人資料 dict 產生完整 vCard 文字

    photo_block 為空時不嵌入 PHOTO，
    macOS 通訊錄會自動依姓氏產生字母頭貼（建議的預設行為）
    """
    cn_surname = data["chinese_surname"]
    cn_given = data["chinese_given"]
    en_name = data["english_name"]      # 含 alias 如「阿明 Ming Wang」
    title = data["title"]
    email = data["email"]
    # mobile 可選：簽呈沒填手機時為空字串 / None，跳過 TEL CELL 整行
    mobile = data.get("mobile") or ""

    cfg = load_company_config()
    co = cfg["company"]
    ph = cfg["phone"]
    addr = cfg["address"]
    vc = cfg["vcard"]

    lines = [
        "BEGIN:VCARD",
        "VERSION:3.0",
        f"PRODID:{vc['product_id']}",
        f"N:{cn_surname};{cn_given};;;",
        f"FN:{cn_given} {cn_surname}",
        f"NICKNAME:{en_name}",
        f"ORG:{co['name_cn']} ({co['name_en']});",
        f"TITLE:{title}",
        f"EMAIL;type=INTERNET;type=pref:{email}",
        # TEL 排序：公司電話 → 手機 → 傳真（對齊 macOS 通訊錄匯出版排序）
        f"TEL;type=WORK;type=VOICE;type=pref:{ph['office_vcard_format']}",
    ]
    if mobile:
        # 手機採本地分組格式 09XX-XXX-XXX（例 0909-050269 → 0909-050-269）
        lines.append(f"TEL;type=CELL;type=VOICE:{format_mobile_local(mobile)}")
    lines.append(f"TEL;type=WORK;type=FAX:{ph['fax_vcard_format']}")
    lines.extend([
        f"ADR;type=WORK;type=pref:;;{addr['street']};{addr['district']};{addr['city']};{addr['postal']};{addr['country']}",
        f"URL;type=WORK;type=pref:{cfg['website']}",
    ])
    if photo_block:
        lines.append(photo_block)
    lines.append("END:VCARD")
    lines.append("")  # 收尾換行
    return "\r\n".join(lines)


def _vcard_url_base() -> str:
    """從 company config 讀 vCard 公開 URL prefix（lazy 讀，支援 runtime 換 config）。"""
    return load_company_config()["vcard"]["url_base"]


# 向後相容：保留模組層級常數，但改用 property-like 函式呼叫
# 既有 callers 直接讀 VCARD_URL_BASE 會拿到模組載入時的值（DEFAULTS）
VCARD_URL_BASE = _vcard_url_base()


def make_vcard(data: dict, output_path: Path, include_photo: bool = False):
    """include_photo=False (預設): 不嵌入 PHOTO，macOS 自動產姓氏頭貼

    產出 vCard 後同時印出公司公開 URL，方便複製貼到 QR Code 產生器
    """
    if include_photo:
        if TEMPLATE_VCF is None:
            raise RuntimeError(
                "include_photo=True 但未設定 SV_VCARD_TEMPLATE 環境變數，請指向樣板 .vcf"
            )
        photo_block = extract_photo_block(TEMPLATE_VCF)
    else:
        photo_block = ""
    content = build_vcard(data, photo_block)
    output_path.write_text(content, encoding="utf-8")
    print(f"OK: 寫入 {output_path} ({output_path.stat().st_size} bytes)")
    public_url = _vcard_url_base() + output_path.name
    print(f"📋 vCard 上傳後 URL:  {public_url}")


if __name__ == "__main__":
    # 測試資料（範例）
    data = {
        "chinese_surname": "王",
        "chinese_given": "小明",
        "english_name": "阿明 Ming Wang",
        "title": "美術設計",
        "email": "mingwang@streetvoice.com",
        "mobile": "0909-050-269",
    }
    output_path = Path("/tmp/MingWang.vcf")
    output_path.parent.mkdir(parents=True, exist_ok=True)
    make_vcard(data, output_path)
