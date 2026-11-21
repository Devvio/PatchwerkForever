"""The pictures of the globe's light and movement (Effects.lua). All our own, drawn here.

    python globe_fx.py      writes Art/Fx/light.blp, sheen.blp, clouds.blp, age.blp, wear.blp and
                            world/look_fx.png, world/look_age.png

    light     the corners of the picture darkened, as by a candle: dark warm brown, clear in the middle
    sheen     a soft white shine, added to the ball where the light falls on it
    clouds    cloud shadows: soft dark blots that repeat left to right and top to bottom, so the picture
              can slide across the globe without a join
    age       what a hundred years on a desk do to a paper globe, for the whole sphere at once (longitude
              across, latitude down, made on the sphere so nothing is squeezed toward the poles): yellowed
              varnish, grime round the pins, water stains with their tide lines, clusters of foxing, and
              paler patches where the paper is rubbed, most of all along the equator where a hand turns it
    wear      the small things, in one square that repeats: hairline cracks in the varnish, fine specks, and
              down its left edge the seam between two strips of the paper (the addon lays it twelve times
              round the globe, so there are twelve strips, as a globe's paper is cut)
"""
import os

import numpy as np
from PIL import Image

from blp import write_blp
from globe_art import ADDON, WORLD

SIZE = 256


def light():
    y, x = np.mgrid[0:SIZE, 0:SIZE].astype(np.float32)
    d = np.hypot((x + 0.5) / SIZE - 0.5, (y + 0.5) / SIZE - 0.5) / 0.5       # 0 in the middle, 1 at a side's middle
    t = np.clip((d - 0.7) / 0.75, 0, 1)
    show = t * t * (3 - 2 * t)
    rgba = np.zeros((SIZE, SIZE, 4), np.uint8)
    rgba[..., :3] = (34, 20, 8)
    rgba[..., 3] = (show * 255).astype(np.uint8)
    return rgba


def sheen():
    y, x = np.mgrid[0:SIZE, 0:SIZE].astype(np.float32)
    d = np.hypot((x + 0.5) / SIZE - 0.5, (y + 0.5) / SIZE - 0.5) / 0.5
    show = np.clip(1 - d, 0, 1) ** 2.2
    rgba = np.zeros((SIZE, SIZE, 4), np.uint8)
    rgba[..., :3] = (255, 244, 220)
    rgba[..., 3] = (show * 255).astype(np.uint8)
    return rgba


def clouds(seed=7):
    """Noise with only its long waves kept (so it repeats at the picture's edges), cut off below a level."""
    rng = np.random.default_rng(seed)
    noise = rng.standard_normal((SIZE, SIZE))
    f = np.fft.fft2(noise)
    fy, fx = np.meshgrid(np.fft.fftfreq(SIZE) * SIZE, np.fft.fftfreq(SIZE) * SIZE, indexing="ij")
    k = np.hypot(fx, fy)
    f *= np.where(k > 0, 1 / np.maximum(k, 1) ** 1.6, 0) * np.exp(-(k / 24) ** 2)
    n = np.real(np.fft.ifft2(f))
    n = (n - n.min()) / (n.max() - n.min())
    show = np.clip((n - 0.54) / 0.3, 0, 1)
    show = show * show * (3 - 2 * show) * 0.5
    rgba = np.zeros((SIZE, SIZE, 4), np.uint8)
    rgba[..., :3] = (44, 34, 24)
    rgba[..., 3] = (show * 255).astype(np.uint8)
    return rgba


class Layers:
    """Washes of colour laid one over another, kept as one see-through picture."""

    def __init__(self, h, w):
        self.rgb = np.zeros((h, w, 3), np.float32)           # (each colour times how much of it shows)
        self.a = np.zeros((h, w), np.float32)

    def over(self, colour, show):
        show = np.clip(show, 0, 1).astype(np.float32)
        self.rgb = np.array(colour, np.float32)[None, None, :] * show[..., None] + self.rgb * (1 - show)[..., None]
        self.a = show + self.a * (1 - show)

    def rgba(self):
        out = np.zeros(self.a.shape + (4,), np.uint8)
        out[..., :3] = np.clip(self.rgb / np.maximum(self.a, 1e-4)[..., None], 0, 255).astype(np.uint8)
        out[..., 3] = (np.clip(self.a, 0, 1) * 255).astype(np.uint8)
        return out


STAIN, RUST, GRIME, RUBBED, CRACK = (112, 76, 34), (134, 78, 32), (84, 58, 30), (234, 224, 198), (66, 44, 22)
AGE_W, AGE_H = 512, 256


def waves(points, rng, count, scale):
    """Smooth noise at points of the sphere (unit vectors): waves in chance directions, about -1 to 1."""
    n = np.zeros(points.shape[:-1], np.float32)
    for _ in range(count):
        k = rng.standard_normal(3)
        k *= scale * rng.uniform(0.6, 1.5) / np.linalg.norm(k)
        n += np.cos(points @ k.astype(np.float32) + rng.uniform(0, 2 * np.pi))
    return n / np.sqrt(count / 2)


def chance_point(rng):
    p = rng.standard_normal(3)
    return (p / np.linalg.norm(p)).astype(np.float32)


def age(seed=11):
    rng = np.random.default_rng(seed)
    lon = (np.arange(AGE_W) + 0.5) / AGE_W * 2 * np.pi - np.pi
    lat = np.pi / 2 - (np.arange(AGE_H) + 0.5) / AGE_H * np.pi
    lon, lat = np.meshgrid(lon, lat)
    points = np.stack([np.cos(lat) * np.cos(lon), np.cos(lat) * np.sin(lon), np.sin(lat)], -1).astype(np.float32)
    out = Layers(AGE_H, AGE_W)
    # yellowed varnish, uneven, and grime gathered round the pins at the poles
    broad = waves(points, rng, 14, 2.2)
    out.over(STAIN, 0.05 + 0.04 * np.clip(broad, -1, 1))
    out.over(GRIME, 0.20 * np.clip((np.abs(lat) - 1.12) / 0.4, 0, 1) ** 1.5)
    # water stains: a faint wash with a darker tide line where it dried, its edge wandering
    # (the edge wanders in waves shorter than a stain is wide, or every stain is a ring from a cup; and the
    # tide line is strong along some of its length and nearly gone along the rest)
    wander = 0.24 * waves(points, rng, 30, 20.0) + 0.09 * waves(points, rng, 30, 48.0)
    broken = waves(points, rng, 24, 12.0)
    for _ in range(13):
        centre, reach = chance_point(rng), rng.uniform(0.10, 0.34)
        d = np.arccos(np.clip(points @ centre, -1, 1)) * (1 + wander)
        strength = rng.uniform(0.5, 1.0)
        line = np.exp(-((d - reach) / (0.008 + reach * 0.03)) ** 2) * np.clip(0.55 + 0.7 * broken, 0.08, 1)
        out.over(STAIN, strength * (0.055 * np.clip((reach - d) / 0.02, 0, 1) + 0.20 * line))
    # foxing: rust-brown spots, in clusters
    spots = np.zeros((AGE_H, AGE_W), np.float32)
    for _ in range(16):
        middle = chance_point(rng)
        for _ in range(int(rng.integers(8, 26))):
            p = middle + rng.standard_normal(3).astype(np.float32) * 0.11
            p /= np.linalg.norm(p)
            size = rng.uniform(0.008, 0.022)
            d = np.arccos(np.clip(points @ p, -1, 1))
            spots = np.maximum(spots, rng.uniform(0.18, 0.42) * np.exp(-(d / size) ** 2))
    out.over(RUST, spots)
    # rubbed pale: along the equator, where a hand turns the globe, and in a few patches
    fine = waves(points, rng, 24, 16.0)
    out.over(RUBBED, 0.13 * np.exp(-(lat / 0.075) ** 2) * np.clip(0.45 + 0.6 * fine, 0, 1))
    for _ in range(12):
        centre, reach = chance_point(rng), rng.uniform(0.08, 0.22)
        d = np.arccos(np.clip(points @ centre, -1, 1))
        out.over(RUBBED, 0.11 * np.exp(-(d / reach) ** 2) * np.clip(0.4 + 0.7 * fine, 0, 1))
    return out.rgba()


def tile_noise(rng, falloff, cut):
    """Noise that repeats at the square's edges, 0 to 1."""
    f = np.fft.fft2(rng.standard_normal((SIZE, SIZE)))
    fy, fx = np.meshgrid(np.fft.fftfreq(SIZE) * SIZE, np.fft.fftfreq(SIZE) * SIZE, indexing="ij")
    k = np.hypot(fx, fy)
    f *= np.where(k > 0, 1 / np.maximum(k, 1) ** falloff, 0) * np.exp(-(k / cut) ** 2)
    n = np.real(np.fft.ifft2(f))
    return (n - n.min()) / (n.max() - n.min())


def wear(seed=23):
    rng = np.random.default_rng(seed)
    y, x = np.mgrid[0:SIZE, 0:SIZE].astype(np.float32)

    def apart(px, py, sx=x, sy=y):                           # (distance in the square, round its edges)
        dx, dy = np.abs(sx - px), np.abs(sy - py)
        return np.hypot(np.minimum(dx, SIZE - dx), np.minimum(dy, SIZE - dy))

    out = Layers(SIZE, SIZE)
    # hairline cracks: the borders between the cells round chance points, wandering, and only here and there
    wx = x + 5 * (tile_noise(rng, 1.4, 18) - 0.5)
    wy = y + 5 * (tile_noise(rng, 1.4, 18) - 0.5)
    seeds = [(rng.uniform(0, SIZE), rng.uniform(0, SIZE)) for _ in range(84)]
    nearest = np.full((SIZE, SIZE), 1e9, np.float32)
    second = np.full((SIZE, SIZE), 1e9, np.float32)
    first_of = np.zeros((SIZE, SIZE), np.int32)
    second_of = np.zeros((SIZE, SIZE), np.int32)
    for i, (sx, sy) in enumerate(seeds):
        d = apart(sx, sy, wx, wy)
        closer, between = d < nearest, (d >= nearest) & (d < second)
        second_of = np.where(closer, first_of, np.where(between, i, second_of))
        second = np.where(closer, nearest, np.where(between, d, second))
        first_of = np.where(closer, i, first_of)
        nearest = np.where(closer, d, nearest)
    # (how far a point is from the border between its two nearest: so a crack is as thin everywhere)
    sx, sy = np.array([s[0] for s in seeds], np.float32), np.array([s[1] for s in seeds], np.float32)
    ax, ay = np.abs(sx[first_of] - sx[second_of]), np.abs(sy[first_of] - sy[second_of])
    between = np.maximum(np.hypot(np.minimum(ax, SIZE - ax), np.minimum(ay, SIZE - ay)), 1)
    off = (second * second - nearest * nearest) / (2 * between)
    here = np.clip((tile_noise(rng, 1.2, 7) - 0.5) / 0.14, 0, 1)
    out.over(CRACK, 0.32 * np.clip(1 - off / 1.0, 0, 1) * here)
    # fine specks
    specks = np.zeros((SIZE, SIZE), np.float32)
    for _ in range(80):
        d = apart(rng.uniform(0, SIZE), rng.uniform(0, SIZE))
        specks = np.maximum(specks, rng.uniform(0.14, 0.4) * np.exp(-(d / rng.uniform(0.6, 1.7)) ** 2))
    out.over(RUST, specks)
    # the seam down the left edge: a dark line, broken a little, and the lifted edge of the next strip pale beside it
    along = 0.55 + 0.45 * tile_noise(rng, 1.0, 30)[:, :1]
    dx = np.minimum(x, SIZE - x)
    out.over(CRACK, 0.30 * np.exp(-(dx / 0.9) ** 2) * along)
    out.over(RUBBED, 0.12 * np.exp(-((x - 2.6) / 1.3) ** 2) * along)
    return out.rgba()


def main():
    out = os.path.join(ADDON, "Art", "Fx")
    os.makedirs(out, exist_ok=True)
    made = {"light": light(), "sheen": sheen(), "clouds": clouds()}
    total = 0
    sheet = Image.new("RGBA", (SIZE * 3, SIZE), (200, 182, 138, 255))
    for i, (name, rgba) in enumerate(made.items()):
        total += write_blp(os.path.join(out, name + ".blp"), rgba)
        sheet.alpha_composite(Image.fromarray(rgba), (i * SIZE, 0))
    sheet.convert("RGB").save(os.path.join(WORLD, "look_fx.png"))
    old = {"age": age(), "wear": wear()}
    for name, rgba in old.items():
        total += write_blp(os.path.join(out, name + ".blp"), rgba)
    # how the aging looks: over the sea's colour and over a land's, the stains for the whole sphere, then the
    # small things twice their size, laid 2 x 2 to show they repeat without a join
    look = Image.new("RGBA", (AGE_W * 2, AGE_H + SIZE * 2), (140, 159, 149, 255))
    look.paste((206, 186, 132, 255), (AGE_W, 0, AGE_W * 2, AGE_H + SIZE * 2))
    stains, small = Image.fromarray(old["age"]), Image.fromarray(old["wear"])
    for i in range(2):
        look.alpha_composite(stains, (i * AGE_W, 0))
        for j in range(4):
            look.alpha_composite(small, (i * AGE_W + (j % 2) * SIZE, AGE_H + (j // 2) * SIZE))
    look.convert("RGB").save(os.path.join(WORLD, "look_age.png"))
    print("written %s (%.0f KB), world/look_fx.png, world/look_age.png" % (", ".join(list(made) + list(old)), total / 1e3))


if __name__ == "__main__":
    main()
