#!/usr/bin/env python3
"""驗證 sidecar JSON schema 對 fixtures。

用法：
    python3 tests/validate_sidecar.py

預期：
    - tests/fixtures/sidecar_valid.json        → 通過
    - tests/fixtures/sidecar_invalid_*.json    → 應該失敗（檔名含 _invalid_ 視為負面樣本）

退出碼：0 = 全符合預期，非 0 = 有預期外的結果
"""

import json
import sys
from pathlib import Path

try:
    import jsonschema
except ImportError:
    sys.exit("ERROR: 需要 jsonschema 套件。請跑 `pip3 install jsonschema`")

TESTS_DIR = Path(__file__).parent
SCHEMA_PATH = TESTS_DIR / "sidecar_schema.json"
FIXTURES_DIR = TESTS_DIR / "fixtures"


def main():
    if not SCHEMA_PATH.is_file():
        sys.exit(f"ERROR: 找不到 schema: {SCHEMA_PATH}")

    schema = json.loads(SCHEMA_PATH.read_text(encoding="utf-8"))
    fixtures = sorted(FIXTURES_DIR.glob("sidecar_*.json"))
    if not fixtures:
        sys.exit(f"ERROR: 沒有找到 fixtures/sidecar_*.json")

    failures = []
    for fx in fixtures:
        is_negative = "_invalid_" in fx.name
        try:
            data = json.loads(fx.read_text(encoding="utf-8"))
            jsonschema.validate(data, schema)
            # 通過 validation
            if is_negative:
                failures.append(f"  ❌ {fx.name}：應該驗證失敗但通過了（負面樣本失靈）")
            else:
                print(f"  ✅ {fx.name}（valid 通過）")
        except jsonschema.ValidationError as e:
            # validation 失敗
            if is_negative:
                first_line = e.message.splitlines()[0][:60]
                print(f"  ✅ {fx.name}（如預期失敗：{first_line}...）")
            else:
                failures.append(f"  ❌ {fx.name}：意外失敗 — {e.message}")

    if failures:
        print()
        for f in failures:
            print(f)
        sys.exit(1)

    print()
    print(f"🎉 {len(fixtures)} 個 fixture 全部符合預期")


if __name__ == "__main__":
    main()
