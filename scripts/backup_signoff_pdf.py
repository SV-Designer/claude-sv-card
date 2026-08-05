#!/usr/bin/env python3
"""簽呈 PDF 備份：保留上方 KEEP_TOP_PX 高度，裁掉下半（含「表單註釋」section 與「簽核列表」）

v0.10.3+ 改動：
- KEEP_TOP_PX = 352 固定值（之前是 pdfplumber 找「表單註釋」word top → 動態）
  原因：中子版 PDF 中文字 layer 圖片化（CID 編碼）pdfplumber 抓不到「表單註釋」word
  改用固定值對 TW + 中子 + 未來新版型一致
- 加 --form-no <N> 參數：覆寫表單號（中子 PDF 也抓不到「表單號:」regex，必傳）
  未傳則 fallback pdfplumber 抓「表單號:」regex（TW 簽呈正常路徑）
  都沒有 → 報錯

用法：
  backup_signoff_pdf.py <pdf-path> <dest-dir> [--form-no <N>]

行為：
  1. 取表單號：CLI --form-no > pdfplumber regex「表單號:XXX」> 報錯
  2. pypdf 改 page.mediabox.lower_left.y = page_h - 352 → 隱藏下方
  3. 寫到 <dest-dir>/簽呈編號-{號碼}.pdf
"""
import sys
import re
import os
import argparse
from typing import Optional
import pypdf

KEEP_TOP_PX = 352  # 保留上方高度，TW + 中子皆適用（v0.10.3 拍板）


def get_form_no(pdf_path: str, override: Optional[str]) -> str:
    """取表單號：CLI 覆寫優先，否則 pdfplumber 抓 regex。"""
    if override:
        return override
    try:
        import pdfplumber
        with pdfplumber.open(pdf_path) as pdf:
            text = pdf.pages[0].extract_text() or ""
        m = re.search(r"表單號\s*[:：]\s*(\d+)", text)
        if m:
            return m.group(1)
    except Exception as e:
        print(f"WARN: pdfplumber 抓表單號失敗: {e}", file=sys.stderr)
    sys.stderr.write(
        "ERROR: 取不到表單號 — pdfplumber 抓不到「表單號:」regex（中子 PDF 圖片化常見）\n"
        "       → 用 --form-no <N> 手動指定\n"
    )
    sys.exit(1)


def main():
    parser = argparse.ArgumentParser(
        description="備份簽呈 PDF，保留上方 352px",
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    parser.add_argument("pdf_path", help="簽呈 PDF 原始路徑")
    parser.add_argument("dest_dir", help="目標資料夾（DEST_DIR）")
    parser.add_argument("--form-no", dest="form_no", default=None,
                        help="表單號（中子 PDF 必傳；TW 不傳時自動 regex 抓）")
    args = parser.parse_args()

    pdf_path, dest_dir = args.pdf_path, args.dest_dir
    if not os.path.isfile(pdf_path):
        sys.stderr.write(f"ERROR: PDF 不存在: {pdf_path}\n")
        sys.exit(1)
    if not os.path.isdir(dest_dir):
        sys.stderr.write(f"ERROR: 目標資料夾不存在: {dest_dir}\n")
        sys.exit(1)

    form_no = get_form_no(pdf_path, args.form_no)

    reader = pypdf.PdfReader(pdf_path)
    writer = pypdf.PdfWriter()
    page = reader.pages[0]
    page_h = float(page.mediabox.height)
    new_lly = page_h - KEEP_TOP_PX

    page.mediabox.lower_left = (float(page.mediabox.lower_left[0]), new_lly)
    page.cropbox.lower_left = (float(page.cropbox.lower_left[0]), new_lly)
    writer.add_page(page)

    out_path = os.path.join(dest_dir, f"簽呈編號-{form_no}.pdf")
    with open(out_path, "wb") as f:
        writer.write(f)

    size = os.path.getsize(out_path)
    print(f"✅ 簽呈 PDF 已備份: {out_path} ({size} bytes)")
    print(f"   表單號={form_no} 保留上方={KEEP_TOP_PX}px → 切點 lower_left.y={new_lly:.1f}")


if __name__ == "__main__":
    main()
