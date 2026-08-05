#!/usr/bin/env python3
"""欄位解析邏輯回歸測試（純函式，不需 PDF / pdfplumber）。

涵蓋 v0.16.1 兩個修正：
1. parse_ext_and_mobile：含空格的手機號碼（+886 909 050 269）不被截斷成 +886
2. 分機去 #：對齊 card_helper.sh init 的 `office_ext.strip().lstrip("#")`
   （簽呈填法不一致：有人填 402、有人填 #321，去 # 後統一）

用法：python3 tests/test_field_logic.py
退出碼：0 = 全過，1 = 有 case 失敗
"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent.parent / "scripts"))
from extract_signoff_fields import parse_ext_and_mobile


def strip_ext_hash(s):
    """對齊 card_helper.sh init 的 office_ext 去 # 處理。"""
    return s.strip().lstrip("#")


# (簽呈全文片段, 期望 office_ext, 期望 mobile)
CASES_EXT_MOBILE = [
    # 核心修正：含空格手機完整抓取（舊版 \S* 會截成 +886）
    ("名片上的室內分機 #321 名片上的個人手機號碼 +886 909 050 269\n名片版型 TW 街聲",
     "#321", "+886 909 050 269"),
    # 一般 dash 格式手機
    ("名片上的室內分機 402 名片上的個人手機號碼 0909-050269\n名片版型 台灣中子",
     "402", "0909-050269"),
    # 手機空白 → None（不跨行誤抓下一行）
    ("名片上的室內分機 395 名片上的個人手機號碼 \n名片版型 TW 街聲",
     "395", None),
    # 分機空白 → None
    ("名片上的室內分機  名片上的個人手機號碼 0900-000-000\n名片版型 TW 街聲",
     None, "0900-000-000"),
]

# (原始 office_ext, 去 # 後期望值)
CASES_STRIP = [
    ("#321", "321"),
    ("402", "402"),
    (" #321 ", "321"),
    ("", ""),
]


def main():
    fails = []

    for text, exp_ext, exp_mob in CASES_EXT_MOBILE:
        ext, mob = parse_ext_and_mobile(text)
        if ext != exp_ext or mob != exp_mob:
            fails.append(
                f"  ❌ parse: 得 ext={ext!r} mob={mob!r}，期望 ext={exp_ext!r} mob={exp_mob!r}"
            )
        else:
            print(f"  ✅ parse: ext={ext!r} mob={mob!r}")

    for raw, exp in CASES_STRIP:
        got = strip_ext_hash(raw)
        if got != exp:
            fails.append(f"  ❌ strip#: {raw!r} → {got!r}，期望 {exp!r}")
        else:
            print(f"  ✅ strip#: {raw!r} → {got!r}")

    if fails:
        print()
        for f in fails:
            print(f)
        sys.exit(1)

    print(f"\n🎉 欄位解析邏輯測試全過（{len(CASES_EXT_MOBILE) + len(CASES_STRIP)} cases）")


if __name__ == "__main__":
    main()
