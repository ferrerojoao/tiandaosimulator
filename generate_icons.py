"""generate_icons.py - 生成宗门和圣地 32x32 像素图标"""
from PIL import Image, ImageDraw
import os

OUT = "assets/tiles"

def draw_sect(img: Image.Image, col: tuple, shape: int = 0) -> Image.Image:
    """宗门图标：0=殿宇, 1=塔，以此类推"""
    d = ImageDraw.Draw(img)
    W = 32
    # 地基
    d.rectangle([6, 20, 26, 28], fill=(col[0]//2, col[1]//2, col[2]//2, 255))
    # 主体
    d.rectangle([8, 10, 24, 22], fill=col)
    # 屋顶三角
    d.polygon([(4, 12), (16, 4), (28, 12)], fill=col)
    # 门
    d.rectangle([12, 18, 20, 22], fill=(col[0]//3, col[1]//3, col[2]//3, 255))
    # 金光
    d.rectangle([14, 6, 18, 8], fill=(255, 220, 100, 255))
    return img

def draw_sacred(img: Image.Image, el_col: tuple, symbol: str) -> Image.Image:
    """圣地图标：发光核心+元素色"""
    d = ImageDraw.Draw(img)
    W = 32
    cx, cy = 16, 16
    # 大光晕
    r = 13
    for i in range(r, 2, -1):
        alpha = 80 - i * 4
        c = (*el_col[:3], max(0, alpha))
        d.ellipse([cx - i, cy - i, cx + i, cy + i], fill=c)
    # 核心
    d.ellipse([cx - 6, cy - 6, cx + 6, cy + 6], fill=el_col)
    # 白心
    d.ellipse([cx - 3, cy - 3, cx + 3, cy + 3], fill=(255, 255, 255))
    return img

# 宗门颜色
sect_colors = [
    (100, 180, 255), # 青云宗
    (120, 220, 140), # 太虚门
    (255, 140, 160), # 天剑阁
    (200, 190, 100), # 碧落宫
    (255, 150, 80),  # 万妖岭
    (180, 120, 255), # 星辰殿
]

# 圣地颜色
elem_colors = [
    (200, 200, 200), # 无
    (255, 200, 60),  # 金
    (80, 220, 80),   # 木
    (60, 180, 255),  # 水
    (255, 80, 40),   # 火
    (180, 130, 60),  # 土
]

os.makedirs(OUT, exist_ok=True)

# 宗门
for i, col in enumerate(sect_colors):
    img = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
    draw_sect(img, col)
    img.save(os.path.join(OUT, f"sect_{i}.png"))

# 圣地
for i, col in enumerate(elem_colors):
    img = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
    draw_sacred(img, col, "")
    img.save(os.path.join(OUT, f"sacred_{i}.png"))

print(f"生成了 {len(sect_colors)} 个宗门图标 + {len(elem_colors)} 个圣地图标 -> {OUT}")
