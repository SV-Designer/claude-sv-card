#!/usr/bin/env python3
"""sv-card 公司固定欄位設定載入器（P1，v0.9.0+）

抽離原本散落於 make_vcard.py / make_card_artifacts.py / card_helper.sh 的
公司中文名 / 統編 / 電話 / FAX / 地址 / vCard URL prefix 等固定欄位。

設計原則：
- 預設讀 ~/.config/sv-card/company.json
- 可用 SV_COMPANY_CONFIG 環境變數覆寫路徑
- 缺檔 / 缺欄位 → fallback 到內建 DEFAULTS（向後相容，現行流程不受影響）
- 解析失敗 → stderr 警告後 fallback DEFAULTS（不中斷主流程）

公司搬家 / 統編變更 / 電話 FAX 變更時：
  1. 編輯 ~/.config/sv-card/company.json
  2. 同時手動更新模板 .ai（templates/*.ai 內的文字框是另一份資料源）

如果未來想完全消除 DEFAULTS，可在 install.sh 強制建立 company.json，
但目前保留以維持「無設定也能跑」的零摩擦體驗。
"""
from pathlib import Path
import json
import os
import sys

DEFAULTS = {
    "company": {
        "name_cn": "街聲股份有限公司",
        "name_en": "StreetVoice",
        "tax_id": "24560657",
    },
    "phone": {
        "office": "+886-2-2741-7065",
        "office_vcard_format": "02-27417065",
        "fax_vcard_format": "02-27488490",
    },
    "address": {
        "street": "松山區光復北路 11 巷 35 號 11 樓",
        "district": "松山區",
        "city": "台北市",
        "postal": "105",
        "country": "台灣",
    },
    "vcard": {
        "url_base": "http://drive.streetvoice.com/vcard/",
        "product_id": "-//StreetVoice CardGen//EN",
    },
    "website": "www.streetvoice.com",
}

_CONFIG_PATH = Path(
    os.environ.get("SV_COMPANY_CONFIG") or "~/.config/sv-card/company.json"
).expanduser()

_cache = None


def _deep_merge(base: dict, override: dict) -> dict:
    """遞迴合併：override 蓋過 base，缺 key 用 base 補。"""
    result = dict(base)
    for k, v in override.items():
        if k in result and isinstance(result[k], dict) and isinstance(v, dict):
            result[k] = _deep_merge(result[k], v)
        else:
            result[k] = v
    return result


def load(force_reload: bool = False) -> dict:
    """載入公司設定，缺檔 / 缺欄位皆走 DEFAULTS。"""
    global _cache
    if _cache is not None and not force_reload:
        return _cache
    if _CONFIG_PATH.exists():
        try:
            override = json.loads(_CONFIG_PATH.read_text(encoding="utf-8"))
            _cache = _deep_merge(DEFAULTS, override)
        except json.JSONDecodeError as e:
            print(
                f"WARN: {_CONFIG_PATH} JSON 解析失敗 ({e})，"
                f"使用內建預設值",
                file=sys.stderr,
            )
            _cache = dict(DEFAULTS)
    else:
        _cache = dict(DEFAULTS)
    return _cache


def company() -> dict:
    return load()["company"]


def phone() -> dict:
    return load()["phone"]


def address() -> dict:
    return load()["address"]


def vcard_config() -> dict:
    return load()["vcard"]


def website() -> str:
    return load()["website"]


if __name__ == "__main__":
    # CLI: 印出目前生效的設定值（debug 用）
    print(json.dumps(load(), ensure_ascii=False, indent=2))
