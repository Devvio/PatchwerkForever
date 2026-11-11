"""Read the numbers out of one of the game's data tables (DB2, format WDC5).

Only numeric fields: text fields come back as their raw offsets. Column
meanings are not stored in the file, so a caller finds a column by a value it
knows (see find_column).

    table = Table(store.read_fdid(1349477))        # Map.db2
    for record_id, fields in table.rows(): ...     # fields: one int (or a list of ints) per column
"""
import struct


class Table:
    def __init__(self, data):
        assert data[:4] == b"WDC5", "not a WDC5 table"
        self.data = data
        (self.record_count, self.field_count, self.record_size, self.string_size,
         _table_hash, _layout_hash, self.min_id, self.max_id, _locale,
         self.flags, self.id_index, self.total_fields, _bitpacked_offset, _lookup_columns,
         storage_size, common_size, pallet_size, section_count) = struct.unpack_from("<9I2H7I", data, 136)
        pos = 136 + struct.calcsize("<9I2H7I")
        self.sections = []
        for _ in range(section_count):
            self.sections.append(struct.unpack_from("<Q8I", data, pos))
            pos += 40
        self.structure = []
        for _ in range(self.total_fields):
            self.structure.append(struct.unpack_from("<hH", data, pos))
            pos += 4
        self.storage = []
        for _ in range(storage_size // 24):
            self.storage.append(struct.unpack_from("<HHIIIII", data, pos))
            pos += 24
        self.pallet_at = pos
        pos += pallet_size
        self.common_at = pos
        # where each column's pallet and common data begin
        self._pallet, self._common = {}, {}
        p, c = self.pallet_at, self.common_at
        for i, (_off, _bits, extra, kind, _v1, _v2, _v3) in enumerate(self.storage):
            if kind in (3, 4):
                self._pallet[i] = p
                p += extra
            elif kind == 2:
                table = {}
                for k in range(extra // 8):
                    rid, value = struct.unpack_from("<II", data, c + k * 8)
                    table[rid] = value
                self._common[i] = table
                c += extra

    @staticmethod
    def _bits(buf, bit_offset, bit_count):
        if bit_count == 0:
            return 0
        first = bit_offset // 8
        last = (bit_offset + bit_count + 7) // 8
        value = int.from_bytes(buf[first:last], "little")
        return (value >> (bit_offset % 8)) & ((1 << bit_count) - 1)

    def _record(self, buf, record_id):
        out = []
        for i, (off, bits, _extra, kind, v1, v2, v3) in enumerate(self.storage):
            if kind == 0:                                   # plain: maybe an array
                size_bits = 32 - self.structure[i][0] if i < len(self.structure) else bits
                if size_bits <= 0 or size_bits > 64:
                    size_bits = bits
                count = max(1, bits // size_bits)
                values = [self._bits(buf, off + k * size_bits, size_bits) for k in range(count)]
                out.append(values[0] if count == 1 else values)
            elif kind in (1, 5):                            # bit-packed
                value = self._bits(buf, off, v2)
                if kind == 5 and v2 and value >> (v2 - 1):
                    value -= 1 << v2
                out.append(value)
            elif kind == 2:                                 # common: a default, with exceptions by record
                out.append(self._common[i].get(record_id, v1))
            elif kind == 3:                                 # an index into the column's pallet
                index = self._bits(buf, off, v2)
                out.append(struct.unpack_from("<I", self.data, self._pallet[i] + index * 4)[0])
            elif kind == 4:                                 # an index into a pallet of arrays
                index = self._bits(buf, off, v2)
                out.append(list(struct.unpack_from("<%dI" % v3, self.data, self._pallet[i] + index * 4 * v3)))
            else:
                out.append(None)
        return out

    def rows(self):
        """(record id, fields) for every readable record; encrypted sections are skipped."""
        data = self.data
        for (key, file_offset, count, strings, records_end, id_list_size,
             relationship_size, offset_map_count, copy_count) in self.sections:
            if count == 0 and offset_map_count == 0:
                continue
            sparse = self.flags & 1
            if sparse:
                records_at, records_len = file_offset, records_end - file_offset
            else:
                records_at, records_len = file_offset, count * self.record_size
            if key and not any(data[records_at: records_at + min(records_len, 4096)]):
                continue                                    # encrypted, no key: all zeroes
            pos = records_at + records_len + (0 if sparse else strings)
            ids = struct.unpack_from("<%dI" % (id_list_size // 4), data, pos)
            pos += id_list_size
            copies = [struct.unpack_from("<II", data, pos + k * 8) for k in range(copy_count)]
            pos += copy_count * 8
            offsets = [struct.unpack_from("<IH", data, pos + k * 6) for k in range(offset_map_count)]
            pos += offset_map_count * 6
            pos += relationship_size
            sparse_ids = struct.unpack_from("<%dI" % offset_map_count, data, pos) if offset_map_count else ()
            seen = {}
            if sparse:
                for k, (offset, size) in enumerate(offsets):
                    if size:
                        record_id = sparse_ids[k] if sparse_ids else (ids[k] if k < len(ids) else self.min_id + k)
                        fields = self._record(data[offset: offset + size + 8], record_id)
                        seen[record_id] = fields
                        yield record_id, fields
            else:
                for k in range(count):
                    buf = data[records_at + k * self.record_size: records_at + (k + 1) * self.record_size + 8]
                    if ids:
                        record_id = ids[k]
                    else:
                        record_id = self._record(buf, 0)[self.id_index]
                    fields = self._record(buf, record_id)
                    seen[record_id] = fields
                    yield record_id, fields
            for new_id, source_id in copies:
                if source_id in seen:
                    yield new_id, seen[source_id]


def texts(table, column):
    """{record id: text} of a text column. A text field holds the distance from the field itself to its text.

    For tables whose records are all of one size (not the sparse kind), which is what the small tables are."""
    data, out = table.data, {}
    assert not table.flags & 1, "a sparse table: texts() does not read these"
    before = 0                                              # records of earlier sections lie between
    total = sum(section[2] for section in table.sections)
    for (key, file_offset, count, strings, _end, id_list_size, _rel, _omc, _copies) in table.sections:
        ids = struct.unpack_from("<%dI" % (id_list_size // 4), data, file_offset + count * table.record_size + strings)
        for k in range(count):
            at = file_offset + k * table.record_size
            fields = table._record(data[at: at + table.record_size + 8], ids[k] if ids else 0)
            record_id = ids[k] if ids else fields[table.id_index]
            # the distance is counted as if every section's records came first, then every section's texts
            where = at + table.storage[column][0] // 8 + fields[column] - (total - before - count) * table.record_size
            if len(table.sections) == 1:
                where = at + table.storage[column][0] // 8 + fields[column]
            end = data.find(b"\0", where)
            out[record_id] = data[where:end].decode("utf-8", "replace") if 0 <= where < len(data) and end >= 0 else ""
        before += count
    return out


def find_column(table, known):
    """The column where each record id in `known` holds the value given: {record id: value}."""
    candidates = None
    for record_id, fields in table.rows():
        if record_id in known:
            hits = {i for i, v in enumerate(fields) if v == known[record_id]}
            candidates = hits if candidates is None else candidates & hits
    return sorted(candidates or [])
