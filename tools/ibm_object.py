# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Jiaxun Yang <jiaxun.yang@flygoat.com>

"""Read the ten-area IBM object format emitted by host_put.PTerminate."""

import struct
from pathlib import Path


def inspect(path):
    data = Path(path).read_bytes()
    limit = len(data)

    def require(condition, message):
        if not condition:
            raise ValueError(message)

    def words(offset, count):
        require(
            offset >= 0
            and offset % 4 == 0
            and count >= 0
            and offset + 4 * count <= limit,
            f"word range outside object: {offset:#x}, {count}",
        )
        return struct.unpack_from(f">{count}I", data, offset)

    def name(offset):
        require(offset < limit, "missing name length")
        length = data[offset]
        require(length <= 31 and offset + 1 + length <= limit, "invalid name length")
        return data[offset + 1 : offset + 1 + length].decode("latin1")

    end, start, physical, kind, _, _, ldata, mapat = words(0, 8)
    require(
        start == 32 and kind == 1 and start <= end <= physical == len(data),
        "invalid file header",
    )
    limit = end
    (count,) = words(mapat, 1)
    require(count == 10, "expected host PUT's ten-area map")
    require(
        mapat >= 32 and ldata >= mapat + 4 + 12 * count, "overlapping object metadata"
    )
    areas = [words(mapat + 4 + 12 * i, 3) for i in range(count)]
    occupied = []
    for i, (offset, size, props) in enumerate(areas, 1):
        if size:
            require(
                start <= offset and offset + size <= mapat,
                f"area {i} outside area data",
            )
            occupied.append((offset, offset + size))
    occupied.sort()
    require(
        all(a[1] <= b[0] for a, b in zip(occupied, occupied[1:])), "overlapping areas"
    )
    heads = words(ldata, 15)
    require(heads[0] == 14, "invalid LDATA count")
    summaries = {}
    # Numeric prefix lengths and optional string fields from PTerminate.
    formats = {
        1: (5, True),
        2: (4, True),
        3: (2, False),
        4: (4, True),
        7: (2, True),
        8: (2, True),
        9: (3, True),
        10: (4, True),
        11: (4, False),
        13: (6, False),
        14: (2, False),
    }
    for index, (size, has_name) in formats.items():
        pointer = heads[index]
        seen = set()
        entries = []
        while pointer:
            require(
                pointer >= ldata + 60 and pointer not in seen,
                f"invalid or cyclic LDATA({index}) link",
            )
            seen.add(pointer)
            record = words(pointer, size)
            entry = {"offset": pointer, "words": record}
            if has_name:
                entry["name"] = name(pointer + 4 * size)
            if index in (3, 14):
                words(pointer + 8, record[1] * 2)
            elif index == 9:
                array = record[1]
                require(array >= ldata + 60, "invalid external data reference array")
                (length,) = words(array, 1)
                words(array + 4, length)
            elif index == 13 and record[3] != 1:
                require(
                    ldata + 60 <= record[5] and record[5] + record[3] <= limit,
                    "invalid initialization payload",
                )
            entries.append(entry)
            pointer = record[0]
        summaries[index] = entries
    return {
        "file": str(path),
        "data_end": end,
        "physical_size": physical,
        "areas": areas,
        "lists": summaries,
    }


def word(data, offset):
    return struct.unpack_from(">I", data, offset)[0]


def put(data, offset, value):
    struct.pack_into(">I", data, offset, value & 0xFFFFFFFF)


def align(value, boundary):
    return (value + boundary - 1) & -boundary
