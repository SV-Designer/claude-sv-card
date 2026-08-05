"""make_qr.py - Generate styled QR code SVG (circle body + square eyes).

樣式對應 qrcode-monkey:
  Body Shape: circle
  Eye Frame Shape: square (default)
  Eye Ball Shape: square (default)
"""

import qrcode
from pathlib import Path

MODULE_SIZE = 31           # px per module (與範例 SVG 一致)
QUIET_ZONE = 2             # modules of border on each side
COLOR = "rgb(0,0,0)"       # 黑色；Illustrator 端會再 recolor 成 #44403F
BG_COLOR = "rgb(255,255,255)"  # 白底會被 Python 端正則剝除

EC_MAP = {
    "L": qrcode.constants.ERROR_CORRECT_L,
    "M": qrcode.constants.ERROR_CORRECT_M,
    "Q": qrcode.constants.ERROR_CORRECT_Q,
    "H": qrcode.constants.ERROR_CORRECT_H,
}


def make_qr(data: str, output_path: Path, error_correction: str = "M") -> Path:
    qr = qrcode.QRCode(
        version=None,
        error_correction=EC_MAP[error_correction],
        box_size=1,
        border=0,
    )
    qr.add_data(data)
    qr.make(fit=True)
    matrix = qr.get_matrix()
    size = len(matrix)

    total = (size + 2 * QUIET_ZONE) * MODULE_SIZE
    offset = QUIET_ZONE * MODULE_SIZE
    radius = MODULE_SIZE / 2

    finder_origins = [(0, 0), (0, size - 7), (size - 7, 0)]

    def in_finder(r: int, c: int) -> bool:
        for fr, fc in finder_origins:
            if fr <= r < fr + 7 and fc <= c < fc + 7:
                return True
        return False

    parts: list[str] = []
    parts.append('<?xml version="1.0" encoding="utf-8"?>')
    parts.append(
        f'<svg xmlns="http://www.w3.org/2000/svg" '
        f'width="{total}" height="{total}" viewBox="0 0 {total} {total}">'
    )
    parts.append(f'<rect id="bg" width="{total}" height="{total}" fill="{BG_COLOR}"/>')
    parts.append("<g>")

    for r in range(size):
        for c in range(size):
            if not matrix[r][c] or in_finder(r, c):
                continue
            cx = offset + c * MODULE_SIZE + radius
            cy = offset + r * MODULE_SIZE + radius
            parts.append(f'<circle cx="{cx}" cy="{cy}" r="{radius}" fill="{COLOR}"/>')

    for fr, fc in finder_origins:
        ox = offset + fc * MODULE_SIZE
        oy = offset + fr * MODULE_SIZE
        outer = 7 * MODULE_SIZE
        hole_off = MODULE_SIZE
        hole_sz = 5 * MODULE_SIZE
        # Hollow ring via even-odd fill: outer 7x7 sub-path + inner 5x5 hole sub-path
        parts.append(
            f'<path fill-rule="evenodd" fill="{COLOR}" '
            f'd="M{ox},{oy} h{outer} v{outer} h-{outer} z '
            f'M{ox + hole_off},{oy + hole_off} h{hole_sz} v{hole_sz} h-{hole_sz} z"/>'
        )
        parts.append(
            f'<rect x="{ox + 2 * MODULE_SIZE}" y="{oy + 2 * MODULE_SIZE}" '
            f'width="{3 * MODULE_SIZE}" height="{3 * MODULE_SIZE}" fill="{COLOR}"/>'
        )

    parts.append("</g>")
    parts.append("</svg>")

    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text("\n".join(parts), encoding="utf-8")
    print(f"OK: 寫入 {output_path}")
    print(f"   QR 版本: {qr.version} ({size}x{size} modules), 容錯: {error_correction}")
    return output_path


if __name__ == "__main__":
    import sys

    if len(sys.argv) < 3:
        print("用法: python make_qr.py <data> <output.svg> [ec_level]")
        sys.exit(1)
    data = sys.argv[1]
    out = Path(sys.argv[2]).expanduser()
    ec = sys.argv[3] if len(sys.argv) > 3 else "M"
    make_qr(data, out, ec)
