"""fix_alpha.py - 把假透明（灰色棋盘格）变成真透明"""
from PIL import Image
import sys, os, glob

if len(sys.argv) > 1:
    files = sys.argv[1:]
else:
    files = glob.glob("assets/tiles/sect_*.png") + glob.glob("assets/tiles/sacred_*.png")

for fpath in files:
    img = Image.open(fpath)
    if img.mode != "RGBA":
        img = img.convert("RGBA")
    pixels = img.load()
    W, H = img.size
    count = 0
    for y in range(H):
        for x in range(W):
            r, g, b, a = pixels[x, y]
            # 检测灰色棋盘格: 灰色调 (r≈g≈b) 且偏亮
            if r == g == b and 180 <= r <= 230:
                pixels[x, y] = (0, 0, 0, 0)
                count += 1
    img.save(fpath)
    print(f"  {fpath}: {count} 像素 → 透明")

print("完成")
