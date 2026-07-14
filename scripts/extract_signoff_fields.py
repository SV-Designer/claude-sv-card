#!/usr/bin/env python3
"""簽呈 PDF 欄位萃取：印 JSON 到 stdout

用法：
  extract_signoff_fields.py <pdf-path>

JSON 欄位：
  form_no, applicant_dept, applicant_name,
  card_name_raw, card_name_cn, surname_cn, given_cn,
  english_name_full, english_alias, english_name_no_alias,
  title, email, office_ext, mobile, template_type, region,
  other_requests, form_remark, form_remark_is_placeholder

設計：純機械萃取，不做語意判斷（typo、特殊備註等留給 Claude 對比 PDF 視覺）。
"""
import sys
import re
import json
import unicodedata
# pdfplumber 改 lazy import（在 extract_fields 內）：讓純函式 parse_ext_and_mobile
# 可被回歸測試 import 而不需安裝 pdfplumber（v0.16.1）

# 常見複姓（兩字）— 涵蓋台灣常見即可，其餘 fallback 取單字
COMPOUND_SURNAMES_CN = {
    "歐陽", "上官", "司徒", "諸葛", "慕容", "皇甫",
    "司馬", "東方", "夏侯", "南宮", "令狐", "宇文",
    "長孫", "軒轅", "鍾離", "尉遲", "鮮于", "公孫",
}

CJK_RE = re.compile(r"[一-鿿]")

# 表單註釋預設 placeholder（系統提示文字，不是申請人填寫的內容）
FORM_REMARK_PLACEHOLDER = "如有業務需求須製作英文版或 CN 版等文字調整請詳加描述"


def has_cjk(s):
    return bool(CJK_RE.search(s))


def split_chinese_name(name_no_emp_id):
    if len(name_no_emp_id) >= 3 and name_no_emp_id[:2] in COMPOUND_SURNAMES_CN:
        return name_no_emp_id[:2], name_no_emp_id[2:]
    return name_no_emp_id[:1], name_no_emp_id[1:]


def split_english_name(en_full):
    en_full = en_full.strip()
    tokens = en_full.split()
    if not tokens:
        return None, ""
    if has_cjk(tokens[0]):
        return tokens[0], " ".join(tokens[1:])
    return None, en_full


def normalize_placeholder(s):
    """把 PDF 抽出的 CJK Compatibility Ideographs / Radicals 全部回正
    （v0.8.6 用手列 5 字會漏掉 ⾯ ⾏ ⽯ 等，v0.8.7 改用 NFKC 統一處理）
    """
    return unicodedata.normalize("NFKC", s)


def parse_ext_and_mobile(text):
    """從簽呈全文抽「室內分機」與「個人手機號碼」（同一行兩欄）。

    手機改用 [^\\n]*（抓整行剩餘），避免「+886 909 050 269」這種含空格的
    號碼被舊版 \\S* 在第一個空格處截斷成「+886」（v0.16.1 修）。
    分機保留原樣（可能含 #，由 card_helper.sh 消費端統一去 #）。
    兩欄皆可空白 → 回 None。回 (office_ext, mobile)。
    """
    m = re.search(
        r"名片上的室內分機[ \t]+(.*?)名片上的個人手機號碼[ \t]*([^\n]*)", text
    )
    if not m:
        return None, None
    ext_raw = m.group(1).strip()
    mob = m.group(2).strip()
    return (ext_raw or None), (mob or None)


def extract_fields(pdf_path):
    import pdfplumber  # lazy（見檔頭說明）
    with pdfplumber.open(pdf_path) as pdf:
        page = pdf.pages[0]
        raw_text = page.extract_text() or ""

    text = normalize_placeholder(raw_text)

    out = {}

    m = re.search(r"表單號[ \t]*[:：][ \t]*(\d+)", text)
    out["form_no"] = m.group(1) if m else None

    m = re.search(r"申請人[ \t]*[:：][ \t]*([^/\s]+)/(\S+?)(?:\s|$)", text)
    out["applicant_dept"] = m.group(1).strip() if m else None
    out["applicant_name"] = m.group(2).strip() if m else None

    m = re.search(r"名片上的姓名[ \t]+(\S+?)[ \t]+公司", text)
    out["card_name_raw"] = m.group(1) if m else None
    if out["card_name_raw"]:
        # 中文姓名欄位後面的「(數字)」一律去掉、絕不進 PH_NAME（例「王小美(454)」→「王小美」）。
        # 全/半形括號 + 全/半形數字都吃（簽呈填法不一致），並去尾端空白（v0.19.x）。
        # 偵測旗標（v0.22.0）：有偵測到員編就標記，main() 會印 ⚠️ 提醒確認名片只印姓名。
        out["card_name_had_employee_id"] = bool(re.search(r"[（(][\d０-９]+[）)]", out["card_name_raw"]))
        cn = re.sub(r"[（(][\d０-９]+[）)]", "", out["card_name_raw"]).strip()
        out["card_name_cn"] = cn
        out["surname_cn"], out["given_cn"] = split_chinese_name(cn)
    else:
        out["card_name_had_employee_id"] = False
        out["card_name_cn"] = out["surname_cn"] = out["given_cn"] = None

    m = re.search(r"名片上的英文名[ \t]+(.+?)[ \t]+名片上的職稱[ \t]+(.+)", text)
    if m:
        en_full = m.group(1).strip()
        out["english_name_full"] = en_full
        out["title"] = m.group(2).strip()
        alias, no_alias = split_english_name(en_full)
        out["english_alias"] = alias
        out["english_name_no_alias"] = no_alias
        # 偵測旗標（v0.22.0）：英文名欄位含中文（中英混填，例「王小美」）→ main() 印 ⚠️
        # 提醒停下問名片 PH_NAME_EN 要印英文/中文/兩者；.vcf 已自動只取 ASCII 英文。
        out["english_name_has_cjk"] = bool(re.search(r"[一-鿿]", en_full))
    else:
        out["english_name_full"] = out["title"] = None
        out["english_alias"] = out["english_name_no_alias"] = None
        out["english_name_has_cjk"] = False

    m = re.search(r"名片上的郵件地址[ \t]+(\S+@\S+)", text)
    out["email"] = m.group(1).strip() if m else None

    # 分機 + 手機（同一行兩欄；分機 / 手機都可能空白）
    # 全檔通則（v0.8.9）：欄位 label 與內容之間用 [ \t] 不用 \s，避免欄位空白時跨行誤抓
    # 手機抽取見 parse_ext_and_mobile（v0.16.1：改 [^\n]* 修含空格號碼被截斷）
    out["office_ext"], out["mobile"] = parse_ext_and_mobile(text)
    # 偵測旗標（v0.22.0）：手機有填但不是乾淨的 10 碼 09 開頭（可能含奇怪分隔、位數不對）。
    # init 的 to_card_mobile 會自動 normalize 成 +886-9XX-XXX-XXX，此旗標讓 main() 印 ⚠️ 提醒核對。
    _mob_digits = re.sub(r"\D", "", out["mobile"] or "")
    if _mob_digits.startswith("886"):
        _mob_digits = "0" + _mob_digits[3:]
    out["mobile_nonstandard"] = bool(out["mobile"]) and not (len(_mob_digits) == 10 and _mob_digits.startswith("09"))

    m = re.search(r"名片版型[ \t]+(.+?)(?:\n|$)", text)
    out["template_type"] = m.group(1).strip() if m else None

    m = re.search(r"所屬地區[ \t]+(\S+)", text)
    out["region"] = m.group(1).strip() if m else None

    # 其他需求：「其他需求」之後到「所屬地區」之前
    # 注意 PDF 內第一個「其他需求」是 Legacy 提示文字（「...其他需求欄中」），
    # 用 greedy .* 吃光前文，只留最後一個「其他需求」之後的內容
    m = re.search(r".*其他需求\s*(.*?)\s*所屬地區", text, re.DOTALL)
    out["other_requests"] = m.group(1).strip() if m else ""

    # 表單註釋：「表單註釋」之後到「簽核列表」之前
    m = re.search(r"表單註釋\s*(.*?)\s*簽核列表", text, re.DOTALL)
    remark = m.group(1).strip() if m else ""
    out["form_remark"] = remark
    out["form_remark_is_placeholder"] = (remark == FORM_REMARK_PLACEHOLDER)

    return out


def main():
    if len(sys.argv) != 2:
        sys.stderr.write("Usage: extract_signoff_fields.py <pdf-path>\n")
        sys.exit(1)
    fields = extract_fields(sys.argv[1])
    print(json.dumps(fields, ensure_ascii=False, indent=2))

    # 全 null 偵測（v0.16.2）：中子系列 PDF 的中文 layer 常被圖片化（CID 編碼），
    # pdfplumber 抓不到中文錨點 → 關鍵欄位全 None。明確標記，提醒走純視覺萃取流程，
    # 避免每次中子 PDF 都困惑「是 PDF 壞了還是圖片化」。
    key_fields = ["form_no", "card_name_raw", "email", "template_type"]
    if all(fields.get(k) is None for k in key_fields):
        sys.stderr.write(
            "⚠️ 關鍵欄位全部抓不到 —— 疑似中文圖片化 PDF（中子 BVI / 台灣中子常見）。\n"
            "   機械萃取對此類 PDF 失效屬正常；請以 Claude 視覺萃取（Read PDF）為準，\n"
            "   並逐欄與使用者人工確認（此時失去機械雙重交叉檢核）。\n"
        )

    # 非常規欄位偵測（v0.22.0）：把「Claude 必看項」機械化，主動印 ⚠️ 提醒該停下確認，
    # 不再只靠 Claude 臨場眼力。三種情況對應三條自動修正規則（vcf 取英文 / 手機 3-3-3 / 姓名去員編）。
    if fields.get("english_name_has_cjk"):
        sys.stderr.write(
            "⚠️ 英文名欄位含中文（中英混填，如「英文 中文」）—— 🛑 停下問使用者：\n"
            "   名片 PH_NAME_EN 要印「只英文 / 只中文 / 中英都印」？（.vcf/URL/QR 已自動只取 ASCII 英文）\n"
        )
    if fields.get("card_name_had_employee_id"):
        sys.stderr.write(
            "⚠️ 中文姓名含員編「(數字)」，已自動去除只留姓名 —— 請確認名片只印姓名、不印員編。\n"
        )
    if fields.get("mobile_nonstandard"):
        sys.stderr.write(
            "⚠️ 手機非標準 10 碼 09 格式，init 會自動 normalize 成 +886-9XX-XXX-XXX —— 請核對號碼正確。\n"
        )


if __name__ == "__main__":
    main()
