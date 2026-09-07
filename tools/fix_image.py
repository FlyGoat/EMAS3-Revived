#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Jiaxun Yang <jiaxun.yang@flygoat.com>

"""Fix IBM objects into EMAS images using explicit guest byte order.

Layouts follow IFIX8S, XACFIX01S, C02BLD and VSMFIX1S in src/. The Director
call list and loader instruction words are read from those maintained sources.
"""

import argparse
import os
import struct
import time
from datetime import datetime, timezone
from pathlib import Path

from ibm_object import align, inspect, put, word

ROOT = Path(__file__).resolve().parents[1]
PAGE = 4096


def timestamp():
    value = int(os.environ.get("SOURCE_DATE_EPOCH", int(time.time())))
    if not 0 <= value <= 0x7FFFFFFF:
        raise ValueError("timestamp outside EMAS packed-date range")
    return value


def source_values(path, names, procedure=None):
    from ximplang.api import parse
    from ximplang.codegen import evaluate

    nodes = parse((ROOT / path).read_text())
    if procedure:
        nodes = next(n.body for n in nodes if getattr(n, "name", "") == procedure)
    result = {}
    for node in nodes:
        if getattr(node, "name", "") in names:
            values = []
            for expression, repeat in node.initial:
                if repeat == "*":
                    break  # The caller supplies the fixed array's zero padding.
                if repeat is not None:
                    raise ValueError("unexpected repetition in image constants")
                values.append(evaluate(expression, {}))
            result[node.name] = values
    if result.keys() != set(names):
        raise ValueError(f"missing image constants in {path}")
    return result


class Object:
    def __init__(self, path):
        self.meta = inspect(path)
        self.raw = Path(path).read_bytes()
        self.end = self.meta["data_end"]
        self.areas = [(0, 0, 0), *self.meta["areas"]]
        self.lists = self.meta["lists"]
        self.output = bytearray(self.raw[: self.end])
        self.warnings = []
        if self.lists[8]:
            raise ValueError("image contains dynamic procedure references")
        if any(self.lists[i] for i in (3, 11, 13)):
            raise ValueError("image contains unsupported load-time operations")

    def location(self, encoded, size=4):
        area, offset = encoded >> 24, encoded & 0xFFFFFF
        if not 1 <= area <= 10 or offset + size > self.areas[area][1]:
            raise ValueError(f"reference outside area: {encoded:08x}")
        return self.areas[area][0] + offset

    def entries(self, loaded, mask_entry=False):
        entries = {}
        for entry in self.lists[1]:
            _, code, gla, ep, pword = entry["words"]
            name = entry["name"]
            if name in entries:
                raise ValueError("duplicate procedure " + name)
            if mask_entry:
                ep &= 0x7FFFFFFF
            entries[name] = (loaded[1] + code, loaded[2] + gla, loaded[1] + ep, pword)
        return entries

    def relocate(
        self,
        loaded,
        *,
        add_descriptor=False,
        stack_top=None,
        external=False,
        signed=True,
    ):
        entries = self.entries(loaded, mask_entry=external)
        data_entries = {
            e["name"]: loaded[e["words"][3]] + e["words"][1] for e in self.lists[4]
        }
        if stack_top is not None:
            data_entries.setdefault("I#STKTOP", stack_top)
        chain = word(self.raw, 24) + 7 * 4
        for ref in self.lists[7]:
            name = ref["name"]
            if name not in entries:
                if not external:
                    raise ValueError("unresolved procedure " + name)
                put(self.output, chain, ref["offset"])
                chain = ref["offset"]
                self.warnings.append("Deferred procedure: " + name)
                continue
            code, gla, ep, pword = entries[name]
            pos = self.location(ref["words"][1], 16)
            expected = word(self.output, pos + 12)
            if expected != pword and (
                not add_descriptor or 0xFFFFFFFF not in (expected, pword)
            ):
                self.warnings.append("Parameter mismatch: " + name)
            put(
                self.output,
                pos,
                code + (word(self.output, pos) if add_descriptor else 0),
            )
            put(
                self.output,
                pos + 4,
                gla + (word(self.output, pos + 4) if add_descriptor else 0),
            )
            put(self.output, pos + 8, ep)
            put(self.output, pos + 12, gla)
        if external:
            put(self.output, chain, 0)
        for ref in self.lists[9]:
            name = ref["name"]
            if name not in data_entries:
                raise ValueError("unresolved data " + name)
            array = ref["words"][1] & 0x7FFFFFFF
            for i in range(word(self.raw, array)):
                pos = self.location(word(self.raw, array + 4 + 4 * i))
                put(self.output, pos, word(self.output, pos) + data_entries[name])
        for block in self.lists[14]:
            for i in range(block["words"][1]):
                loc, base = struct.unpack_from(
                    ">2I", self.raw, block["offset"] + 8 + 8 * i
                )
                offset = base & 0xFFFFFF
                if signed and offset & 0x800000:
                    offset -= 0x1000000
                pos = self.location(loc)
                put(
                    self.output,
                    pos,
                    word(self.output, pos) + loaded[base >> 24] + offset,
                )
        return entries

    def finish(self, used):
        self.output.extend(bytes(max(0, align(used, PAGE) - len(self.output))))
        return bytes(self.output[: align(used, PAGE)])


def supervisor(obj):
    areas = obj.areas
    loaded = {i: 0x400000 + areas[i][0] for i in (1, 4, 6, 10)}
    loaded[2] = 0x800000
    loaded[5] = loaded[2] + areas[2][1]
    loaded[7] = loaded[5] + areas[5][1]
    loaded[8] = loaded[7] + areas[7][1]
    loaded[9] = loaded[8] + areas[8][1]
    size = obj.end + areas[9][1] + PAGE
    obj.output = bytearray(align(size, PAGE))
    obj.output[: areas[9][0]] = obj.raw[: areas[9][0]]
    entries = obj.relocate(loaded, add_descriptor=True)
    code, gla, ep, _ = entries["ENTER"]
    put(obj.output, 12, code)
    put(obj.output, 16, gla)
    put(obj.output, 28, ep)
    old = areas[2][0]
    new = align(old, PAGE)
    length = sum(areas[i][1] for i in (2, 5, 7, 8, 9))
    obj.output[new : new + length] = obj.output[old : old + length]
    put(obj.output, 0, new + length)
    put(obj.output, 24, new)
    put(obj.output, 20, timestamp() | 0x80000000)
    return obj.finish(new + length)


def loader(obj):
    if obj.areas[9][1]:
        raise ValueError("loader requires initialized own arrays")
    loaded = {i: 0x8000 + obj.areas[i][0] for i in (1, 2, 4, 6, 10)}
    loaded[5] = loaded[2] + obj.areas[2][1]
    loaded[9] = 0  # Empty zero-UST descriptors retain a null base.
    entries = obj.relocate(loaded, stack_top=0x8008, signed=False)
    pages = align(obj.end, PAGE) // PAGE
    put(obj.output, 0, pages * PAGE)
    put(obj.output, 16, entries["ENTER"][2])
    put(obj.output, 8, 0x100000)
    output = bytearray((pages + 3) * PAGE)
    put(output, 0, len(output))
    put(output, 4, PAGE)
    put(output, 8, len(output))
    output[3 * PAGE : 3 * PAGE + obj.end] = obj.output
    tables = source_values(
        "src/chopsupe/xacfix01s.imp", ("iplrec", "entrycode"), "xachopfix"
    )
    for start, name, count in ((PAGE, "iplrec", 6), (0x2800, "entrycode", 32)):
        values = tables[name]
        if len(values) > count:
            raise ValueError("loader instruction table too large")
        struct.pack_into(
            f">{count}I",
            output,
            start,
            *([v & 0xFFFFFFFF for v in values] + [0] * (count - len(values))),
        )
    remaining, pos, seek_data, address, track, first = (
        pages + 2,
        8192,
        9216,
        0x8000,
        0,
        2,
    )
    while True:
        for _ in range(first, 10):
            if pos + 8 > 9216:
                raise ValueError("loader CCW chain exceeds its reserved space")
            put(output, pos, 0x06000000 | address)
            put(output, pos + 4, 0x40001000)
            address += PAGE
            if address == 0x20000:
                address = 0x21000  # Guest IPL simulator's reserved page.
            pos += 8
        remaining -= 9
        if remaining <= 0:
            break
        track += 1
        if seek_data + 8 > 0x2800 or pos + 32 > 9216 or track >= 15:
            raise ValueError("loader exceeds one-cylinder IPL layout")
        output[seek_data : seek_data + 7] = bytes((0, 0, 0, 0, 0, track, 1))
        for first_word, second_word in (
            (0x07000000 | (seek_data - PAGE), 0x40000006),
            (0x23000000, 0x40000001),
            (0x31000000 | (seek_data + 2 - PAGE), 0x40000005),
            (0x08000000 | (pos + 16 - PAGE), 0),
        ):
            put(output, pos, first_word)
            put(output, pos + 4, second_word)
            pos += 8
        seek_data += 8
        first = 0
    put(output, pos - 4, PAGE)
    return bytes(output)


def director(obj):
    constants = source_values(
        "src/director/c02bld.imp",
        ("proc", "directorvsn", "codeseg", "segshift", "topjvalue"),
    )
    base = constants["codeseg"][0] << constants["segshift"][0]
    loaded = {i: base + obj.areas[i][0] for i in (1, 2, 4, 6, 10)}
    loaded[5] = 0
    entries = obj.relocate(loaded)
    ep = entries["DIRLDR"][2]
    put(obj.output, 16, 0x47F0C000 | ((ep & 0xFFF) - 28))
    put(obj.output, 24, obj.areas[2][0])
    put(obj.output, 28, obj.areas[2][1] + obj.areas[5][1])
    put(obj.output, 8, obj.areas[2][0])
    sct = align(word(obj.raw, 24), 128)
    names = constants["proc"]
    if len(names) != constants["topjvalue"][0] or names != sorted(set(names)):
        raise ValueError("invalid Director system-call order")
    end = sct + 32 + 48 * len(names)
    obj.output.extend(bytes(max(0, end - len(obj.output))))
    put(obj.output, 0, end)
    put(obj.output, 12, sct)
    now = timestamp()
    struct.pack_into(">4I", obj.output, sct, len(names) + 1, 32, 32, now | 0x80000000)
    date = datetime.fromtimestamp(now, timezone.utc)
    month = (
        "JAN",
        "FEB",
        "MAR",
        "APR",
        "MAY",
        "JUN",
        "JUL",
        "AUG",
        "SEP",
        "OCT",
        "NOV",
        "DEC",
    )[date.month - 1]
    text = f"{constants['directorvsn'][0]} {date.day:02} {month} {date.year % 100:02}".encode(
        "ascii"
    )
    if len(text) > 15:
        raise ValueError("Director version/date exceeds SCT string capacity")
    obj.output[sct + 16 : sct + 17 + len(text)] = bytes([len(text)]) + text
    for i, name in enumerate(names):
        pos = sct + 32 + 48 * i
        encoded = name.encode("ascii")
        obj.output[pos : pos + 1 + len(encoded)] = bytes([len(encoded)]) + encoded
        struct.pack_into(">4I", obj.output, pos + 32, *entries[name])
    return obj.finish(end)


def executive(obj):
    loaded = {i: (75 << 20) + obj.areas[i][0] for i in (1, 4, 6, 10)}
    loaded[2] = align((75 << 20) + obj.end, 1 << 20)
    loaded[7] = loaded[2] + obj.areas[2][1]
    loaded[5] = loaded[7] + obj.areas[7][1]
    loaded[8] = loaded[5] + obj.areas[5][1]
    loaded[9] = loaded[8] + obj.areas[8][1]
    entries = obj.relocate(loaded, external=True)
    put(obj.output, 16, entries["START"][2])
    put(obj.output, 8, obj.areas[2][0])
    put(obj.output, 12, obj.areas[2][1] + obj.areas[5][1])
    return obj.finish(obj.end)


def build(kind, source):
    obj = Object(source)
    data = {
        "supervisor": supervisor,
        "loader": loader,
        "director": director,
        "executive": executive,
    }[kind](obj)
    return data, obj.warnings


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "kind", choices=("supervisor", "loader", "director", "executive")
    )
    parser.add_argument("object", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    try:
        data, warnings = build(args.kind, args.object)
        args.output.write_bytes(data)
    except (OSError, ValueError, KeyError, struct.error) as error:
        parser.exit(1, f"{args.kind} image: {error}\n")
    for warning in warnings:
        print(warning)
    print(f"{args.output}: {len(data) // PAGE} pages")


if __name__ == "__main__":
    main()
