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
import pdfplumber

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


def extract_fields(pdf_path):
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
        cn = re.sub(r"\(\d+\)", "", out["card_name_raw"])
        out["card_name_cn"] = cn
        out["surname_cn"], out["given_cn"] = split_chinese_name(cn)
    else:
        out["card_name_cn"] = out["surname_cn"] = out["given_cn"] = None

    m = re.search(r"名片上的英文名[ \t]+(.+?)[ \t]+名片上的職稱[ \t]+(.+)", text)
    if m:
        en_full = m.group(1).strip()
        out["english_name_full"] = en_full
        out["title"] = m.group(2).strip()
        alias, no_alias = split_english_name(en_full)
        out["english_alias"] = alias
        out["english_name_no_alias"] = no_alias
    else:
        out["english_name_full"] = out["title"] = None
        out["english_alias"] = out["english_name_no_alias"] = None

    m = re.search(r"名片上的郵件地址[ \t]+(\S+@\S+)", text)
    out["email"] = m.group(1).strip() if m else None

    # 分機 + 手機（同一行兩欄；分機 / 手機都可能空白）
    # 全檔通則（v0.8.9）：欄位 label 與內容之間用 [ \t] 不用 \s，避免欄位空白時跨行誤抓
    # （v0.8.7 先在「手機後」加此保護，v0.8.9 推廣到所有欄位 regex）
    m = re.search(r"名片上的室內分機[ \t]+(.*?)名片上的個人手機號碼[ \t]*(\S*)", text)
    if m:
        ext_raw = m.group(1).strip()
        out["office_ext"] = ext_raw if ext_raw else None
        mob = m.group(2).strip()
        out["mobile"] = mob if mob else None
    else:
        out["office_ext"] = out["mobile"] = None

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


if __name__ == "__main__":
    main()
