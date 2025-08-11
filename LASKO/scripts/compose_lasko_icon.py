import os
from collections import deque
from PIL import Image, ImageFilter, ImageOps

ICON_DIR = "/Users/starkers/Projects/Zeroa/LASKO/LASKO/Assets.xcassets/AppIcon.appiconset"
GLYPH_PATH = os.path.join(ICON_DIR, "Lasko-Icon-FULL.svg.png")
BASE_OUT = os.path.join(ICON_DIR, "ios-marketing-1024.png")

W = H = 1024
BASE_COLOR = (239, 170, 58, 255)  # #EFAA3A


def build_sandstone_background() -> Image.Image:
    bg = Image.new("RGBA", (W, H), BASE_COLOR)
    noise = Image.effect_noise((W, H), 70).convert("L").filter(ImageFilter.GaussianBlur(0.8))
    def clamp(v: float) -> int:
        return max(0, min(255, int(v)))
    dark = (clamp(239*0.85), clamp(170*0.85), clamp(58*0.85), 255)
    light = (clamp(239*1.10), clamp(170*1.10), clamp(58*1.10), 255)
    tex = Image.composite(Image.new("RGBA", (W, H), dark), bg, noise.point(lambda p: int(p*0.30)))
    tex = Image.composite(Image.new("RGBA", (W, H), light), tex, ImageOps.invert(noise).point(lambda p: int(p*0.15)))
    return tex


def remove_outer_white_only(glyph: Image.Image) -> Image.Image:
    px = glyph.load()
    w0, h0 = glyph.size
    visited = [[False]*w0 for _ in range(h0)]
    q: deque[tuple[int,int]] = deque()
    TH = 245
    def is_white(x: int, y: int) -> bool:
        r, g, b, a = px[x, y]
        return a > 0 and r >= TH and g >= TH and b >= TH
    # seed borders
    for x in range(w0):
        if is_white(x, 0):
            q.append((x, 0)); visited[0][x] = True
        if is_white(x, h0-1):
            q.append((x, h0-1)); visited[h0-1][x] = True
    for y in range(h0):
        if is_white(0, y):
            q.append((0, y)); visited[y][0] = True
        if is_white(w0-1, y):
            q.append((w0-1, y)); visited[y][w0-1] = True
    # BFS flood fill
    while q:
        x, y = q.popleft()
        r, g, b, a = px[x, y]
        px[x, y] = (r, g, b, 0)
        for nx, ny in ((x-1,y),(x+1,y),(x,y-1),(x,y+1)):
            if 0 <= nx < w0 and 0 <= ny < h0 and not visited[ny][nx]:
                if is_white(nx, ny):
                    visited[ny][nx] = True
                    q.append((nx, ny))
    return glyph


def compose() -> None:
    if not os.path.isfile(GLYPH_PATH):
        raise FileNotFoundError(f"Glyph not found: {GLYPH_PATH}")
    canvas = build_sandstone_background()
    glyph = Image.open(GLYPH_PATH).convert("RGBA")
    glyph = remove_outer_white_only(glyph)
    # Trim and center with 6% padding
    bbox = glyph.split()[-1].getbbox()
    if bbox:
        glyph = glyph.crop(bbox)
    pad = int(W*0.06)
    max_w = W - 2*pad
    max_h = H - 2*pad
    gw, gh = glyph.size
    s = min(max_w/gw, max_h/gh)
    glyph = glyph.resize((max(1, int(gw*s)), max(1, int(gh*s))), Image.LANCZOS)
    x = (W - glyph.size[0]) // 2
    y = (H - glyph.size[1]) // 2
    out = canvas.copy(); out.paste(glyph, (x, y), glyph)
    out.save(BASE_OUT)
    print("WROTE_BASE", BASE_OUT)


if __name__ == "__main__":
    compose()
