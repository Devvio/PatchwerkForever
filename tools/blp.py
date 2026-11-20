"""Write pictures in the game's own format (BLP2), compressed as the game's own are (DXT).

    from blp import write_blp
    write_blp(path, rgba)          rgba: a numpy array, height x width x 4, uint8; sides powers of two
                                   DXT1 when every pixel is opaque, else DXT5; all mipmaps down to 1 x 1
    python blp.py check            round trip: a test picture written, read back, compared

The format (BLP2, as the game reads it):
    "BLP2", version 1, encoding 2 (DXT), alpha bits (0 or 8), alpha type (0: DXT1, 7: DXT5),
    has mipmaps (1), width, height, 16 mipmap offsets, 16 mipmap sizes, a palette of 256 (unused,
    always there: 1024 bytes), then the mipmaps.
DXT1, a 4 x 4 block in 8 bytes: two colours (RGB 5:6:5, the first the larger, so four colours in all:
the two and two between) and a 2-bit choice a pixel. DXT5, in 16 bytes: two alphas and a 3-bit choice of
eight a pixel, then a DXT1 block for the colours. Colours are chosen by the simplest good way: the
block's darkest and lightest along each channel, each pixel the nearest of the four.

Pillow and numpy only for the tools; nothing here goes in an addon but the pictures it writes.
"""
import struct
import sys

import numpy as np


def _blocks(img):
    """height x width x 4 -> (blocks, 16, 4), the 4 x 4 blocks in rows (padded by repeating the edge)."""
    h, w = img.shape[:2]
    ph, pw = (4 - h % 4) % 4, (4 - w % 4) % 4
    if ph or pw:
        img = np.pad(img, ((0, ph), (0, pw), (0, 0)), mode="edge")
    h, w = img.shape[:2]
    return img.reshape(h // 4, 4, w // 4, 4, 4).transpose(0, 2, 1, 3, 4).reshape(-1, 16, 4)


def _to565(rgb):
    rgb = rgb.astype(np.uint32)
    return ((rgb[..., 0] >> 3) << 11) | ((rgb[..., 1] >> 2) << 5) | (rgb[..., 2] >> 3)


def _from565(c):
    c = c.astype(np.uint32)
    r, g, b = (c >> 11) & 31, (c >> 5) & 63, c & 31
    return np.stack([(r << 3) | (r >> 2), (g << 2) | (g >> 4), (b << 3) | (b >> 2)], axis=-1).astype(np.float32)


def _colour_blocks(blocks):
    """(n, 16, 4) -> (n, 8) bytes of DXT1 colour blocks (four-colour mode)."""
    rgb = blocks[..., :3].astype(np.float32)
    hi, lo = rgb.max(axis=1), rgb.min(axis=1)
    c0, c1 = _to565(hi), _to565(lo)
    swap = c0 < c1
    c0, c1 = np.where(swap, c1, c0), np.where(swap, c0, c1)
    e0, e1 = _from565(c0), _from565(c1)
    palette = np.stack([e0, e1, (2 * e0 + e1) / 3, (e0 + 2 * e1) / 3], axis=1)          # (n, 4, 3)
    dist = ((rgb[:, :, None, :] - palette[:, None, :, :]) ** 2).sum(axis=-1)             # (n, 16, 4)
    idx = dist.argmin(axis=-1).astype(np.uint32)
    idx[c0 == c1] = 0                                                                     # (one colour: all the first)
    bits = (idx << (2 * np.arange(16, dtype=np.uint32))).sum(axis=1).astype(np.uint32)
    out = np.zeros((len(blocks), 8), dtype=np.uint8)
    out[:, 0], out[:, 1] = c0 & 255, c0 >> 8
    out[:, 2], out[:, 3] = c1 & 255, c1 >> 8
    for k in range(4):
        out[:, 4 + k] = (bits >> (8 * k)) & 255
    return out


def _alpha_blocks(blocks):
    """(n, 16, 4) -> (n, 8) bytes of DXT5 alpha blocks (eight-alpha mode)."""
    a = blocks[..., 3].astype(np.float32)
    a0, a1 = a.max(axis=1), a.min(axis=1)
    k = np.arange(8, dtype=np.float32)
    # (choice 0 is a0, 1 is a1, 2 to 7 between, from a0 toward a1)
    weights = np.array([0, 7, 1, 2, 3, 4, 5, 6], dtype=np.float32) / 7
    levels = np.floor(a0[:, None] * (1 - weights[None, :]) + a1[:, None] * weights[None, :] + 0.5)   # (n, 8)
    idx = np.abs(a[:, :, None] - levels[:, None, :]).argmin(axis=-1).astype(np.uint64)
    idx[a0 == a1] = 0
    bits = (idx << (3 * np.arange(16, dtype=np.uint64))).sum(axis=1).astype(np.uint64)
    out = np.zeros((len(blocks), 8), dtype=np.uint8)
    out[:, 0], out[:, 1] = a0.astype(np.uint8), a1.astype(np.uint8)
    for j in range(6):
        out[:, 2 + j] = ((bits >> np.uint64(8 * j)) & np.uint64(255)).astype(np.uint8)
    del k
    return out


def _encode(img, alpha):
    blocks = _blocks(img)
    colour = _colour_blocks(blocks)
    if alpha:
        return np.concatenate([_alpha_blocks(blocks), colour], axis=1).tobytes()
    return colour.tobytes()


def _half(img):
    """The next mipmap: each 2 x 2 averaged (a side of 1 stays 1)."""
    h, w = img.shape[:2]
    f = img.astype(np.float32)
    if h > 1:
        f = (f[0::2] + f[1::2]) / 2
    if w > 1:
        f = (f[:, 0::2] + f[:, 1::2]) / 2
    return np.floor(f + 0.5).astype(np.uint8)


def write_blp(path, rgba):
    rgba = np.ascontiguousarray(rgba, dtype=np.uint8)
    h, w = rgba.shape[:2]
    assert rgba.shape[2] == 4, "the picture needs four channels (RGBA)"
    assert h & (h - 1) == 0 and w & (w - 1) == 0, "the sides must be powers of two"
    alpha = bool((rgba[..., 3] < 255).any())
    mips, img = [], rgba
    while True:
        mips.append(_encode(img, alpha))
        if img.shape[0] == 1 and img.shape[1] == 1 or len(mips) == 16:
            break
        img = _half(img)
    offsets, sizes, at = [], [], 1172
    for m in mips:
        offsets.append(at)
        sizes.append(len(m))
        at += len(m)
    offsets += [0] * (16 - len(offsets))
    sizes += [0] * (16 - len(sizes))
    header = b"BLP2" + struct.pack("<I4B2I", 1, 2, 8 if alpha else 0, 7 if alpha else 0, 1, w, h)
    header += struct.pack("<16I", *offsets) + struct.pack("<16I", *sizes) + b"\0" * 1024
    with open(path, "wb") as f:
        f.write(header)
        for m in mips:
            f.write(m)
    return at


# ------------------------------------------------------------------ reading back, for the checks
def _decode_colour(data, n):
    b = np.frombuffer(data, dtype=np.uint8).reshape(n, 8)
    c0 = b[:, 0].astype(np.uint32) | (b[:, 1].astype(np.uint32) << 8)
    c1 = b[:, 2].astype(np.uint32) | (b[:, 3].astype(np.uint32) << 8)
    e0, e1 = _from565(c0), _from565(c1)
    palette = np.stack([e0, e1, (2 * e0 + e1) / 3, (e0 + 2 * e1) / 3], axis=1)
    bits = b[:, 4].astype(np.uint32) | (b[:, 5].astype(np.uint32) << 8) | (b[:, 6].astype(np.uint32) << 16) | (b[:, 7].astype(np.uint32) << 24)
    idx = (bits[:, None] >> (2 * np.arange(16, dtype=np.uint32))) & 3
    return np.take_along_axis(palette, idx[:, :, None].astype(np.int64), axis=1)


def _decode_alpha(data, n):
    b = np.frombuffer(data, dtype=np.uint8).reshape(n, 8)
    a0, a1 = b[:, 0].astype(np.float32), b[:, 1].astype(np.float32)
    weights = np.array([0, 7, 1, 2, 3, 4, 5, 6], dtype=np.float32) / 7
    levels = np.floor(a0[:, None] * (1 - weights[None, :]) + a1[:, None] * weights[None, :] + 0.5)
    bits = np.zeros(n, dtype=np.uint64)
    for j in range(6):
        bits |= b[:, 2 + j].astype(np.uint64) << np.uint64(8 * j)
    idx = (bits[:, None] >> (3 * np.arange(16, dtype=np.uint64))) & np.uint64(7)
    return np.take_along_axis(levels, idx.astype(np.int64), axis=1)


def read_blp(path):
    """The first (largest) picture of a BLP this module wrote, as height x width x 4."""
    data = open(path, "rb").read()
    assert data[:4] == b"BLP2"
    _, enc, abits, atype, _, w, h = struct.unpack_from("<I4B2I", data, 4)
    assert enc == 2
    offsets = struct.unpack_from("<16I", data, 20)
    sizes = struct.unpack_from("<16I", data, 84)
    raw = data[offsets[0]:offsets[0] + sizes[0]]
    n = ((h + 3) // 4) * ((w + 3) // 4)
    if abits:
        both = np.frombuffer(raw, dtype=np.uint8).reshape(n, 16)
        alpha = _decode_alpha(both[:, :8].tobytes(), n)
        colour = _decode_colour(both[:, 8:].tobytes(), n)
    else:
        colour = _decode_colour(raw, n)
        alpha = np.full((n, 16), 255, dtype=np.float32)
    px = np.concatenate([colour, alpha[:, :, None]], axis=-1)                  # (n, 16, 4)
    px = px.reshape((h + 3) // 4, (w + 3) // 4, 4, 4, 4).transpose(0, 2, 1, 3, 4).reshape((h + 3) // 4 * 4, (w + 3) // 4 * 4, 4)
    return np.floor(px[:h, :w] + 0.5).astype(np.uint8), [s for s in sizes if s]


def check():
    import os
    import tempfile
    rng = np.random.default_rng(1)
    y, x = np.mgrid[0:64, 0:128]
    img = np.zeros((64, 128, 4), dtype=np.uint8)
    img[..., 0] = (x * 2) % 256
    img[..., 1] = (y * 4) % 256
    img[..., 2] = 128
    img[..., 3] = 255
    img[20:30, 40:60, :3] = (200, 30, 30)
    with tempfile.TemporaryDirectory() as d:
        p = os.path.join(d, "t.blp")
        size = write_blp(p, img)
        back, mips = read_blp(p)
        err = np.abs(back.astype(int) - img.astype(int))[..., :3].mean()
        assert len(mips) == 8 and mips[0] == 64 * 128 // 2, (mips, "DXT1: 8 bytes a 4 x 4 block, mipmaps to 1 x 1")
        assert err < 6, ("DXT1 too far from the picture", err)
        print("DXT1: %d bytes, mean error %.2f, %d mipmaps" % (size, err, len(mips)))
        img[..., 3] = (x * 2) % 256
        img[0:4, 0:4, 3] = 0
        write_blp(p, img)
        back, mips = read_blp(p)
        aerr = np.abs(back.astype(int) - img.astype(int))[..., 3].mean()
        assert mips[0] == 64 * 128 and aerr < 3 and (back[0:4, 0:4, 3] == 0).all(), (mips[0], aerr)
        print("DXT5: mean alpha error %.2f" % aerr)
    print("blp: all passed.")
    del rng


if __name__ == "__main__":
    if sys.argv[1:] == ["check"]:
        check()
    else:
        print(__doc__)
