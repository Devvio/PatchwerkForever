"""Read files out of a local World of Warcraft install (CASC storage).

Pure standard library. Reads only; nothing in the install is changed.

    store = Storage(r"G:/Games/World of Warcraft", product="wowf")
    data = store.read_fdid(782779)      # a file by its FileDataID, or None

How the storage is laid out:
  .build.info                      one line per installed product, with its build key
  Data/config/xx/yy/<build key>    the build's config: the root and encoding files' hashes
  Data/data/NN########.idx         16 index files: 9-byte encoded key -> archive, offset, size
  Data/data/data.NNN               the archives: BLTE-packed files, 30-byte header each
  encoding file                    content key -> encoded key
  root file                        FileDataID -> content key (per locale / content flags)
"""
import bisect
import os
import struct
import zlib


class Storage:
    def __init__(self, base, product="wowf"):
        self.base = base
        self.data_dir = os.path.join(base, "Data", "data")
        self.build_key = self._build_key(product)
        self.config = self._read_config(self.build_key)
        self._idx = self._load_indices()
        self._archives = {}
        self.encrypted = 0          # chunks skipped because they are encrypted
        self._enc = None
        self._root = None

    # ---- build config -------------------------------------------------
    def _build_key(self, product):
        with open(os.path.join(self.base, ".build.info"), encoding="utf-8") as f:
            lines = f.read().splitlines()
        cols = [c.split("!")[0] for c in lines[0].split("|")]
        for line in lines[1:]:
            row = dict(zip(cols, line.split("|")))
            if row.get("Product") == product:
                return row["Build Key"]
        raise KeyError("product %r is not installed here" % product)

    def _read_config(self, key):
        path = os.path.join(self.base, "Data", "config", key[0:2], key[2:4], key)
        out = {}
        with open(path, encoding="utf-8") as f:
            for line in f:
                if " = " in line:
                    name, value = line.rstrip("\n").split(" = ", 1)
                    out[name] = value.split(" ")
        return out

    # ---- index files ---------------------------------------------------
    def _load_indices(self):
        newest = {}
        for name in os.listdir(self.data_dir):
            if name.endswith(".idx"):
                bucket, version = int(name[0:2], 16), int(name[2:10], 16)
                if bucket not in newest or version > newest[bucket][0]:
                    newest[bucket] = (version, name)
        out = {}
        for bucket, (_, name) in newest.items():
            with open(os.path.join(self.data_dir, name), "rb") as f:
                raw = f.read()
            header_size = struct.unpack_from("<I", raw, 0)[0]
            version, _b, _extra, size_bytes, offs_bytes, key_bytes, seg_bits = struct.unpack_from("<HBBBBBB", raw, 8)
            assert (size_bytes, offs_bytes, key_bytes) == (4, 5, 9), "unexpected index layout"
            pos = (8 + header_size + 15) & ~15          # entries block, 16-byte aligned
            entries_size = struct.unpack_from("<I", raw, pos)[0]
            start = pos + 8
            count = entries_size // 18
            keys = [raw[start + i * 18: start + i * 18 + 9] for i in range(count)]
            out[bucket] = (raw, start, keys, seg_bits)
        return out

    @staticmethod
    def _bucket(key9):
        x = 0
        for b in key9:
            x ^= b
        return (x & 0xF) ^ (x >> 4)

    def _locate(self, ekey):
        key9 = bytes(ekey[:9])
        raw, start, keys, seg_bits = self._idx[self._bucket(key9)]
        i = bisect.bisect_left(keys, key9)
        if i >= len(keys) or keys[i] != key9:
            return None
        at = start + i * 18 + 9
        high, low = raw[at], struct.unpack_from(">I", raw, at + 1)[0]
        packed = (high << 32) | low
        archive = packed >> seg_bits
        offset = packed & ((1 << seg_bits) - 1)
        size = struct.unpack_from("<I", raw, at + 5)[0]
        return archive, offset, size

    # ---- archives and BLTE ---------------------------------------------
    def _archive(self, n):
        f = self._archives.get(n)
        if f is None:
            f = open(os.path.join(self.data_dir, "data.%03d" % n), "rb")
            self._archives[n] = f
        return f

    def read_ekey(self, ekey):
        where = self._locate(ekey)
        if where is None:
            return None
        archive, offset, size = where
        f = self._archive(archive)
        f.seek(offset)
        blob = f.read(size)
        return self._blte(blob[30:])

    def _blte(self, blob):
        assert blob[:4] == b"BLTE", "not a BLTE file"
        header_size = struct.unpack_from(">I", blob, 4)[0]
        if header_size == 0:
            return self._chunk(blob[8:])
        count = struct.unpack_from(">I", blob, 8)[0] & 0xFFFFFF
        out, pos, at = [], header_size, 12
        for _ in range(count):
            comp, _decomp = struct.unpack_from(">II", blob, at)
            at += 24
            out.append(self._chunk(blob[pos:pos + comp], _decomp))
            pos += comp
        return b"".join(out)

    def _chunk(self, chunk, decomp=0):
        mode = chunk[0:1]
        if mode == b"N":
            return chunk[1:]
        if mode == b"Z":
            return zlib.decompress(chunk[1:])
        if mode == b"E":
            self.encrypted += 1
            return b"\0" * decomp      # no key: left as zeroes
        raise ValueError("unknown BLTE chunk mode %r" % mode)

    # ---- encoding: content key -> encoded key ---------------------------
    def _encoding(self):
        if self._enc is None:
            data = self.read_ekey(bytes.fromhex(self.config["encoding"][1]))
            assert data[:2] == b"EN"
            _ver, ck_size, ek_size, ck_page_kb, _ek_page_kb, ck_pages, _ek_pages, _unk, espec = struct.unpack_from(">BBBHHIIBI", data, 2)
            assert (ck_size, ek_size) == (16, 16)
            index_at = 22 + espec
            pages_at = index_at + ck_pages * 32
            firsts = [data[index_at + i * 32: index_at + i * 32 + 16] for i in range(ck_pages)]
            self._enc = (data, firsts, pages_at, ck_page_kb * 1024)
        return self._enc

    def ekey_of(self, ckey):
        data, firsts, pages_at, page_size = self._encoding()
        i = bisect.bisect_right(firsts, ckey) - 1
        if i < 0:
            return None
        pos = pages_at + i * page_size
        end = pos + page_size
        while pos < end:
            count = data[pos]
            if count == 0:
                break
            key = data[pos + 6: pos + 22]
            if key == ckey:
                return data[pos + 22: pos + 38]
            pos += 22 + 16 * count
        return None

    def read_ckey(self, ckey):
        ekey = self.ekey_of(ckey)
        return self.read_ekey(ekey) if ekey else None

    # ---- root: FileDataID -> content key --------------------------------
    def _load_root(self):
        if self._root is not None:
            return self._root
        data = self.read_ckey(bytes.fromhex(self.config["root"][0]))
        blocks = []
        pos, version = 0, 0
        if data[:4] == b"TSFM":
            a, b = struct.unpack_from("<II", data, 4)
            if a < 1000:                       # header size, then version
                version = b
                pos = a
            else:                              # total and named file counts
                pos, version = 12, 1
        n = len(data)
        while pos < n:
            if version >= 2:
                count, locale, c1, c2, c3 = struct.unpack_from("<IIIIB", data, pos)
                flags = c1 | c2 | (c3 << 17)
                pos += 17
            else:
                count, flags, locale = struct.unpack_from("<III", data, pos)
                pos += 12
            deltas = struct.unpack_from("<%di" % count, data, pos)
            pos += 4 * count
            fdids, cur = [], -1
            for d in deltas:
                cur += d + 1
                fdids.append(cur)
            keys_at = pos
            pos += 16 * count
            if version == 0 or not (flags & 0x10000000):
                pos += 8 * count               # name hashes
            blocks.append((fdids, keys_at, locale, flags))
        self._root = (data, blocks)
        return self._root

    def ckeys_of(self, fdid):
        """Every (content key, locale flags, content flags) the root holds for a FileDataID."""
        data, blocks = self._load_root()
        out = []
        for fdids, keys_at, locale, flags in blocks:
            i = bisect.bisect_left(fdids, fdid)
            if i < len(fdids) and fdids[i] == fdid:
                out.append((data[keys_at + i * 16: keys_at + i * 16 + 16], locale, flags))
        return out

    def read_fdid(self, fdid):
        for ckey, _locale, _flags in self.ckeys_of(fdid):
            data = self.read_ckey(ckey)
            if data is not None:
                return data
        return None
