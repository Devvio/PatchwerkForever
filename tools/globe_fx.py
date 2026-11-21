"""The pictures of the globe's light and movement (Effects.lua). All our own, drawn here.

    python globe_fx.py      writes Art/Fx/light.blp, sheen.blp, clouds.blp and world/look_fx.png

    light     the corners of the picture darkened, as by a candle: dark warm brown, clear in the middle
    sheen     a soft white shine, added to the ball where the light falls on it
    clouds    cloud shadows: soft dark blots that repeat left to right and top to bottom, so the picture
              can slide across the globe without a join
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
    print("written %s (%.0f KB), world/look_fx.png" % (", ".join(made), total / 1e3))


if __name__ == "__main__":
    main()
