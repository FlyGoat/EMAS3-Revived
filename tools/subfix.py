#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Jiaxun Yang <jiaxun.yang@flygoat.com>

"""Build a subsystem basefile from IBM PUT objects and a fixed Director."""

import argparse
import struct
from pathlib import Path

from ibm_object import align, inspect, put, word

BASE = 75 << 20
PRIME = 251


def name_hash(name):
    raw = name.encode("latin1")
    selected = raw[:4] + raw[-4:] if len(raw) > 8 else (raw + b"<>#@!+&")[:8]
    return (
        sum(a * b for a, b in zip(selected, (71, 47, 97, 79, 29, 37, 53, 59))) % PRIME
    )


def director_entries(data):
    sct = word(data, 12)
    count = word(data, sct) - 1
    start = sct + word(data, sct + 8)
    if not 0 < count <= 256 or start + 48 * count > len(data):
        raise ValueError("invalid Director SCT")
    entries = {}
    for i in range(count):
        pos = start + 48 * i
        length = data[pos]
        if not 0 < length <= 31:
            raise ValueError("invalid SCT name")
        name = data[pos + 1 : pos + 1 + length].decode("latin1")
        if name in entries:
            raise ValueError("duplicate SCT name " + name)
        entries[name] = struct.unpack_from(">4I", data, pos + 32)
    return entries, word(data, sct + 12)


def build(source, director):
    meta = inspect(source)
    raw = Path(source).read_bytes()
    sct, stamp = director_entries(Path(director).read_bytes())
    areas = [(0, 0, 0), *meta["areas"]]
    lists = meta["lists"]
    # This format predates separate statics/I/O/zero-UST sections. Refuse to
    # silently map sections for which the archived SUBFIX has no loaded base.
    if any(areas[i][1] for i in (3, 7, 8, 9)) or lists[8]:
        raise ValueError("SUBFIX requires a consolidated GLA and static imports")
    loaded = {i: BASE + areas[i][0] for i in (1, 2, 4, 6, 10)}
    loaded[5] = loaded[2] + areas[2][1]

    def location(encoded):
        area, offset = encoded >> 24, encoded & 0xFFFFFF
        if not 1 <= area <= 10 or offset + 4 > areas[area][1]:
            raise ValueError(f"invalid reference location {encoded:08x}")
        return areas[area][0] + offset

    entries = {}
    for entry in lists[1]:
        _, co, gl, ep, pw = entry["words"]
        name = entry["name"]
        if name in entries:
            raise ValueError("duplicate procedure " + name)
        entries[name] = (loaded[1] + co, loaded[2] + gl, loaded[1] + ep, pw)
    if "SSINIT" not in entries:
        raise ValueError("missing SSINIT")
    data_entries = {
        e["name"]: (e["words"][2], loaded[e["words"][3]] + e["words"][1])
        for e in lists[4]
    }
    output = bytearray(raw[: meta["data_end"]])
    output.extend(bytes(align(len(output), 4096) - len(output)))
    reloc_at = len(output)
    output.extend(bytes(8))
    new_relocs = []
    retained = []
    chain = word(raw, 24) + 7 * 4
    for ref in lists[7]:
        name = ref["name"]
        descriptor = entries.get(name, sct.get(name))
        if descriptor is None:
            raise ValueError("unresolved procedure " + name)
        pos = location(ref["words"][1])
        co, gl, ep, pw = descriptor
        if word(raw, pos + 12) != pw:
            raise ValueError("parameter mismatch " + name)
        for i, value in enumerate(
            (co, gl, ep, 0x04100000 | ((pw >> 4) & 0xF000) | (pw & 0xFFFF))
        ):
            put(output, pos + 4 * i, value)
        if name in entries:
            new_relocs.append((ref["words"][1] + 4, 0x02000000))
        else:
            put(output, chain, ref["offset"])
            chain = ref["offset"]
            retained.append(name)
    put(output, chain, 0)
    for ref in lists[9]:
        name = ref["name"]
        if name in data_entries:
            address = data_entries[name][1]
        elif name == "EMAS3TOPSTK":
            address = 0x04C38020  # SUBFIX's guest SSOWN.topstk field.
        else:
            raise ValueError("unresolved data " + name)
        array = ref["words"][1] & 0x7FFFFFFF
        for i in range(word(raw, array)):
            pos = location(word(raw, array + 4 + 4 * i))
            put(output, pos, word(output, pos) + address)
    for block in lists[14]:
        for i in range(block["words"][1]):
            loc, base = struct.unpack_from(">II", raw, block["offset"] + 8 + 8 * i)
            offset = base & 0xFFFFFF
            if offset & 0x800000:
                offset -= 0x1000000
            pos = location(loc)
            put(output, pos, word(output, pos) + loaded[base >> 24] + offset)
    for pair in new_relocs:
        output.extend(struct.pack(">2I", *pair))
    put(output, reloc_at, word(raw, word(raw, 24) + 14 * 4))
    put(output, reloc_at + 4, len(new_relocs))
    put(output, word(raw, 24) + 14 * 4, reloc_at)
    output.extend(bytes(align(len(output), 4096) - len(output)))
    table = len(output)
    output.extend(bytes((PRIME + 1) * 4))
    tails = {}

    def add_entry(name, kind, descriptor):
        encoded = name.encode("latin1")
        slot = name_hash(name)
        pos = len(output)
        length = align(len(encoded) + 1, 4)
        output.extend(b"\xff" * (length + 8 + 4 * len(descriptor)))
        output[pos] = len(encoded)
        output[pos + 1 : pos + 1 + len(encoded)] = encoded
        put(output, tails.get(slot, table + 4 * slot), pos - table)
        put(output, pos + length, kind)
        for i, value in enumerate(descriptor):
            put(output, pos + length + 8 + 4 * i, value)
        tails[slot] = pos + length + 4

    for name, descriptor in entries.items():
        if name != "S#GO":
            add_entry(name, 2 | (descriptor[2] & 0x80000000), descriptor)
    for entry in lists[4]:
        _, disp, size, area = entry["words"]
        # ADDBASEENTRIES maps these historical unshared areas to base GLA.
        base = loaded[2] if area in (2, 3, 5, 6) else loaded[area]
        add_entry(entry["name"], 1, (size, base + disp))
    unshared = len(lists[9]) + sum(e["name"] != "EMAS3TOPSTK" for e in lists[4]) > 1
    output.extend(
        struct.pack(
            ">3I",
            int.from_bytes(b"SSys", "big"),
            0xFFFFFFFD if unshared or stamp == 1 else stamp,
            table,
        )
    )
    put(output, 0, len(output))
    put(output, 8, areas[2][0])
    put(output, 12, areas[2][1] + areas[5][1])
    put(output, 16, entries["SSINIT"][2])
    output.extend(bytes(align(len(output), 4096) - len(output)))
    return bytes(output), {
        "pages": len(output) // 4096,
        "entry": entries["SSINIT"][2],
        "director_refs": len(retained),
        "loader_entries": len(entries) + len(data_entries),
        "new_relocations": len(new_relocs),
        "loadtable": table,
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("object", type=Path)
    parser.add_argument("director", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    try:
        data, report = build(args.object, args.director)
        args.output.write_bytes(data)
    except (OSError, ValueError, KeyError, struct.error) as error:
        parser.exit(1, f"SUBFIX: {error}\n")
    print(f"{args.output}: {report['pages']} pages")


if __name__ == "__main__":
    main()
