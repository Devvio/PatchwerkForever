"""Draw the small pictures Thread (Globe) marks places with.

    python globe_marks.py

Writes each as a 64 x 64, 32-bit TGA into the addon's Media folder (mark_<name>.tga), and a sheet of
all of them, on parchment and on dark, into world/media_preview/globe_marks.png to look at here.
Every shape is drawn from the numbers in this file: none is copied from anywhere.

    badge     a pale disc with an ink rim: a numbered stop or quest (the game tints it)
    pin       a red map pin
    pinoff    the same, grey: the pin while it is not the one tracked
    boat      an anchor on a blue disc
    zeppelin  an airship on a tan disc
    flight    a wing on a green disc (where the game has no picture of its own for a flight point)
    flightoff the same, grey: a flight point you have not found
    bang      a gold !: a quest to pick up
    ask       a gold ?: a quest to hand in
    person    a small pale disc with an ink rim: one of your group (tinted with their class's colour)
    grave     a headstone: where you died
    place     a pale diamond: a place with no picture of its own
    ring      a soft ring: the area a quest is done in (tinted)
    dot       a small soft dot: the end of a stretch of trail (tinted)
"""
import math
import os
import struct

from PIL import Image, ImageDraw, ImageFilter

HERE = os.path.dirname(os.path.abspath(__file__))
MEDIA = os.path.normpath(os.path.join(HERE, "..", "addons", "PatchwerkForever_Thread_Globe", "Media"))
PREVIEW = os.path.join(HERE, "world", "media_preview")

BIG, SIZE = 512, 64
INK = (38, 26, 14, 255)
PALE = (247, 240, 222, 255)


def at(x, y):
    """A place in the picture: x, y from -1 to 1, y up."""
    return ((x + 1) / 2 * BIG, (1 - y) / 2 * BIG)


def canvas():
    img = Image.new("RGBA", (BIG, BIG), (0, 0, 0, 0))
    return img, ImageDraw.Draw(img)


def disc(d, r, fill, rim=INK, width=0.11, x=0.0, y=0.0):
    d.ellipse([at(x - r, y + r), at(x + r, y - r)], fill=rim)
    r -= width
    d.ellipse([at(x - r, y + r), at(x + r, y - r)], fill=fill)


def line(d, points, width, fill=INK):
    pts = [at(*p) for p in points]
    w = int(width / 2 * BIG)
    d.line(pts, fill=fill, width=w, joint="curve")
    for p in (pts[0], pts[-1]):
        d.ellipse([p[0] - w / 2, p[1] - w / 2, p[0] + w / 2, p[1] + w / 2], fill=fill)


def arc(cx, cy, r, a0, a1, n=40):
    return [(cx + r * math.cos(math.radians(a0 + (a1 - a0) * i / n)), cy + r * math.sin(math.radians(a0 + (a1 - a0) * i / n)))
            for i in range(n + 1)]


def outlined(shape, fill, grow=0.07):
    """A shape (drawn in white on clear by `shape`) in `fill`, with an ink edge round it."""
    mask_img, d = canvas()
    shape(d, (255, 255, 255, 255))
    mask = mask_img.getchannel("A")
    wide = mask.filter(ImageFilter.MaxFilter(int(grow * BIG / 2) * 2 + 1))
    img = Image.new("RGBA", (BIG, BIG), (0, 0, 0, 0))
    img.paste(Image.new("RGBA", (BIG, BIG), INK), (0, 0), wide)
    img.paste(Image.new("RGBA", (BIG, BIG), fill), (0, 0), mask)
    return img


def badge():
    img, d = canvas()
    disc(d, 0.86, PALE, width=0.13)
    return img


def pin(colour):
    def shape(d, fill):
        d.ellipse([at(-0.46, 0.84), at(0.46, -0.08)], fill=fill)
        d.polygon([at(-0.40, 0.18), at(0.40, 0.18), at(0, -0.86)], fill=fill)
    img = outlined(shape, colour)
    d = ImageDraw.Draw(img)
    d.ellipse([at(-0.17, 0.55), at(0.17, 0.21)], fill=PALE)
    return img


def boat():
    img, d = canvas()
    disc(d, 0.86, (120, 170, 205, 255))
    line(d, [(0, 0.34), (0, -0.50)], 0.20)                       # the shank
    line(d, [(-0.26, 0.16), (0.26, 0.16)], 0.18)                 # the stock
    line(d, arc(0, -0.12, 0.40, 200, 340), 0.18)                 # the arms
    d.ellipse([at(-0.14, 0.60), at(0.14, 0.32)], outline=INK, width=int(0.07 * BIG))
    return img


def zeppelin():
    img, d = canvas()
    disc(d, 0.86, (214, 178, 120, 255))
    d.ellipse([at(-0.56, 0.38), at(0.56, -0.12)], fill=INK)      # the bag
    d.polygon([at(-0.52, 0.13), at(-0.70, 0.40), at(-0.70, -0.14)], fill=INK)   # its fin
    d.rectangle([at(-0.18, -0.30), at(0.22, -0.46)], fill=INK)   # the car
    line(d, [(-0.12, -0.12), (-0.12, -0.32)], 0.05)
    line(d, [(0.16, -0.12), (0.16, -0.32)], 0.05)
    return img


def flight(colour):
    img, d = canvas()
    disc(d, 0.86, colour)
    # a wing: three feathers swept back from a shoulder
    for i, (reach, drop) in enumerate(((0.62, 0.34), (0.50, 0.08), (0.36, -0.16))):
        line(d, [(-0.46, 0.20 - i * 0.04), (-0.10, drop + 0.10), (reach - 0.12, drop)], 0.17)
    return img


def bang():
    def shape(d, fill):
        d.polygon([at(-0.19, 0.86), at(0.19, 0.86), at(0.10, -0.22), at(-0.10, -0.22)], fill=fill)
        d.ellipse([at(-0.17, -0.44), at(0.17, -0.78)], fill=fill)
    return outlined(shape, (255, 209, 0, 255))


def ask():
    def shape(d, fill):
        pts = arc(0, 0.42, 0.34, 170, -55) + [(0.02, -0.02), (0.0, -0.24)]
        p = [at(*q) for q in pts]
        w = int(0.14 * BIG)
        d.line(p, fill=fill, width=w, joint="curve")
        for q in (p[0], p[-1]):
            d.ellipse([q[0] - w / 2, q[1] - w / 2, q[0] + w / 2, q[1] + w / 2], fill=fill)
        d.ellipse([at(-0.17, -0.46), at(0.17, -0.80)], fill=fill)
    return outlined(shape, (255, 209, 0, 255))


def person():
    img, d = canvas()
    disc(d, 0.66, PALE, width=0.17)
    return img


def grave():
    def shape(d, fill):
        d.ellipse([at(-0.42, 0.80), at(0.42, -0.04)], fill=fill)
        d.rectangle([at(-0.42, 0.38), at(0.42, -0.62)], fill=fill)
        d.rectangle([at(-0.62, -0.50), at(0.62, -0.74)], fill=fill)
    img = outlined(shape, (176, 172, 164, 255))
    d = ImageDraw.Draw(img)
    line(d, [(0, 0.50), (0, -0.14)], 0.10)
    line(d, [(-0.20, 0.28), (0.20, 0.28)], 0.10)
    return img


def place():
    def shape(d, fill):
        d.polygon([at(0, 0.62), at(0.62, 0), at(0, -0.62), at(-0.62, 0)], fill=fill)
    return outlined(shape, PALE, grow=0.09)


def soft(inner, outer, peak):
    """White, its alpha by the distance from the middle: 0 at `inner`, 1 at `peak`, 0 at `outer`."""
    img = Image.new("RGBA", (BIG, BIG), (255, 255, 255, 0))
    px = img.load()
    for j in range(BIG):
        for i in range(BIG):
            r = math.hypot((i + 0.5) / BIG * 2 - 1, (j + 0.5) / BIG * 2 - 1)
            if inner < r < outer:
                t = (r - inner) / (peak - inner) if r < peak else (outer - r) / (outer - peak)
                t = max(0.0, min(1.0, t))
                px[i, j] = (255, 255, 255, int(255 * t * t * (3 - 2 * t)))
    return img


MARKS = {
    "badge": badge,
    "pin": lambda: pin((206, 44, 32, 255)),
    "pinoff": lambda: pin((150, 146, 140, 255)),
    "boat": boat,
    "zeppelin": zeppelin,
    "flight": lambda: flight((118, 190, 96, 255)),
    "flightoff": lambda: flight((160, 158, 150, 255)),
    "bang": bang,
    "ask": ask,
    "person": person,
    "grave": grave,
    "place": place,
    "ring": lambda: soft(0.62, 0.98, 0.86),
    "dot": lambda: soft(-0.2, 0.9, 0.0001),
}


def write_tga(path, img):
    """Uncompressed, 32 bits, rows from the bottom up, 8 bits of alpha."""
    width, height = img.size
    px = img.load()
    with open(path, "wb") as f:
        f.write(struct.pack("<BBBHHBHHHHBB", 0, 0, 2, 0, 0, 0, 0, 0, width, height, 32, 8))
        for j in range(height - 1, -1, -1):
            f.write(b"".join(bytes((px[i, j][2], px[i, j][1], px[i, j][0], px[i, j][3])) for i in range(width)))


def main():
    os.makedirs(MEDIA, exist_ok=True)
    os.makedirs(PREVIEW, exist_ok=True)
    names = list(MARKS)
    sheet = Image.new("RGBA", (len(names) * 80, 240), (0, 0, 0, 255))
    ImageDraw.Draw(sheet).rectangle([0, 0, sheet.width, 80], fill=(222, 204, 160, 255))
    ImageDraw.Draw(sheet).rectangle([0, 80, sheet.width, 160], fill=(70, 96, 60, 255))
    ImageDraw.Draw(sheet).rectangle([0, 160, sheet.width, 240], fill=(30, 30, 34, 255))
    for n, name in enumerate(names):
        # (the colour of clear pixels is that of the nearest drawn one, so the game's smoothing does not
        # bring a dark fringe in from them)
        big = MARKS[name]()
        small = big.resize((SIZE, SIZE), Image.LANCZOS)
        write_tga(os.path.join(MEDIA, "mark_%s.tga" % name), small)
        for row in range(3):
            sheet.alpha_composite(small, (n * 80 + 8, row * 80 + 8))
            tiny = big.resize((20, 20), Image.LANCZOS)
            sheet.alpha_composite(tiny, (n * 80 + 56, row * 80 + 56))
        lit = sum(1 for p in small.get_flattened_data() if p[3] > 8)
        print("%-10s %d%% of it drawn" % (name, 100 * lit // (SIZE * SIZE)))
    sheet.save(os.path.join(PREVIEW, "globe_marks.png"))
    print("sheet:", os.path.join(PREVIEW, "globe_marks.png"))


if __name__ == "__main__":
    main()
