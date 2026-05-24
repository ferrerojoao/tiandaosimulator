"""split_sprites.py - 把宫格图切成小图标
用法: python split_sprites.py input.png [sect|sacred|cult|auto]
  sect   → sect_0~15
  sacred → sacred_0~15
  cult   → cultivator_0~15  
  auto   → 按文件名含sacred/cult/修士判断（默认）
"""
from PIL import Image
import sys, os

if len(sys.argv) < 2:
    print("用法: python split_sprites.py input.png [sect|sacred|cult|auto]")
    sys.exit(1)

mode = sys.argv[2] if len(sys.argv) > 2 else "auto"
fname = os.path.splitext(os.path.basename(sys.argv[1]))[0].lower()
if mode == "auto":
    if "sacred" in fname: mode = "sacred"
    elif "cult" in fname or "修士" in fname: mode = "cult"
    else: mode = "sect"

src = Image.open(sys.argv[1])
W, H = src.size
cell_w = W // 4
cell_h = H // 4

out_dir = "assets/tiles"
os.makedirs(out_dir, exist_ok=True)

if mode == "sacred":
    cols = 4
    cell_w = W // 4
    mapping = [(f"sacred_{i}", i) for i in range(16)]
elif mode == "cult":
    cols = 4
    cell_w = W // 4
    mapping = [(f"cultivator_{i}", i) for i in range(16)]
else:
    cols = 4
    mapping = [(f"sect_{i}", i) for i in range(16)]

target_size = (128, 128)
for name, idx in mapping:
    r, c = idx // 4, idx % 4
    cell = src.crop((c * cell_w, r * cell_h, (c + 1) * cell_w, (r + 1) * cell_h))
    cell = cell.resize(target_size, Image.LANCZOS)
    path = os.path.join(out_dir, name + ".png")
    cell.save(path)
    print(f"  {path}")

print(f"完成: {len(mapping)} 个图标 ({mode}) → {out_dir}/")
