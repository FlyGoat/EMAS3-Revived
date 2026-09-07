#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Jiaxun Yang <jiaxun.yang@flygoat.com>

"""Combine ten-area IBM PUT objects; IFIX performs final symbol resolution."""

import argparse
import struct
from pathlib import Path


def add(a, b):
    value = a + b
    if not 0 <= value <= 0xFFFFFFFF:
        raise ValueError("object size overflow")
    return value


def align(n, a):
    return add(n, a - 1) & -a


def put(data, p, n):
    struct.pack_into(">I", data, p, n)


class Object:
    def __init__(self, path):
        self.path = path
        self.data = path.read_bytes()
        self.end = len(self.data)
        if not 32 <= self.end <= 0xFFFFFFFF:
            raise ValueError("invalid input size")
        end = self.word(0)
        if (self.word(4), self.word(8), self.word(12)) != (
            32,
            self.end,
            1,
        ) or not 32 <= end <= self.end:
            raise ValueError("invalid IBM object header")
        self.end = end
        self.ldata = self.word(24)
        self.map = self.word(28)
        if (
            self.map < 32
            or self.word(self.map) != 10
            or self.ldata < add(self.map, 124)
            or self.word(self.ldata) != 14
        ):
            raise ValueError("expected ten-area PUT object")
        self.metadata = add(self.ldata, 60)
        self.span(self.ldata, 60)
        self.start = [0] * 11
        self.length = [0] * 11
        self.props = [0] * 11
        self.base = [0] * 11
        for a in range(1, 11):
            p = self.map + 4 + (a - 1) * 12
            self.start[a], self.length[a], self.props[a] = [
                self.word(p + i) for i in (0, 4, 8)
            ]
            if self.length[a]:
                if (
                    a == 3
                    or not 32 <= self.start[a] <= self.map
                    or self.length[a] > self.map - self.start[a]
                ):
                    raise ValueError("invalid area bounds")
                for b in range(1, a):
                    if (
                        self.length[b]
                        and self.start[a] < self.start[b] + self.length[b]
                        and self.start[b] < self.start[a] + self.length[a]
                    ):
                        raise ValueError("overlapping areas")
        self.heads = [0] + [self.word(self.ldata + i * 4) for i in range(1, 15)]
        if any(
            h and i not in (1, 4, 7, 8, 9, 12, 14) for i, h in enumerate(self.heads)
        ):
            raise ValueError(
                "unsupported load-data list (common, bound or initialization)"
            )

    def span(self, p, n):
        if p < 0 or n < 0 or p > self.end or n > self.end - p:
            raise ValueError("record outside object data")

    def word(self, p):
        self.span(p, 4)
        if p & 3:
            raise ValueError("unaligned metadata word")
        return struct.unpack_from(">I", self.data, p)[0]

    def metaptr(self, p):
        if not p:
            return 0
        if not self.metadata <= p < self.end or p & 3:
            raise ValueError("invalid metadata pointer")
        return add(p, self.delta)

    def name_length(self, p):
        self.span(p, 1)
        n = self.data[p]
        if not 1 <= n <= 31:
            raise ValueError("invalid external name")
        self.span(p + 1, n)
        return n

    def location(self, v, signed=False):
        a = v >> 24
        d = v & 0xFFFFFF
        if not 1 <= a <= 10 or a == 3:
            raise ValueError("unsupported area number")
        if signed and d & 0x800000:
            d -= 0x1000000
        if not signed and d >= self.length[a]:
            raise ValueError("location outside component area")
        d += self.base[a]
        if not (-0x800000 if signed else 0) <= d <= (0x7FFFFF if signed else 0xFFFFFF):
            raise ValueError("combined area displacement overflow")
        return a << 24 | d & 0xFFFFFF

    def copy_list(self, out, kind, head):
        p = self.heads[kind]
        seen = set()
        while p:
            if p in seen:
                raise ValueError("cyclic load-data list")
            seen.add(p)
            dst = self.metaptr(p)
            nextp = self.word(p)
            if kind == 1:
                self.span(p, align(21 + self.name_length(p + 20), 4))
                for off, a in ((4, 1), (8, 2), (12, 1)):
                    put(out, dst + off, add(self.word(p + off), self.base[a]))
            elif kind == 4:
                self.span(p, align(17 + self.name_length(p + 16), 4))
                a = self.word(p + 12)
                if not 1 <= a <= 10 or a == 3:
                    raise ValueError("invalid data entry area")
                put(out, dst + 4, add(self.word(p + 4), self.base[a]))
            elif kind in (7, 8):
                self.span(p, align(9 + self.name_length(p + 8), 4))
                put(out, dst + 4, self.location(self.word(p + 4)))
            elif kind == 9:
                self.span(p, align(13 + self.name_length(p + 12), 4))
                array = self.word(p + 4)
                if array & 0x80000000:
                    raise ValueError("common data references are not supported")
                to = self.metaptr(array)
                length = self.word(array)
                if length > (self.end - array - 4) // 4:
                    raise ValueError("invalid reference array")
                put(out, dst + 4, to)
                for i in range(length):
                    put(
                        out, to + 4 + i * 4, self.location(self.word(array + 4 + i * 4))
                    )
            elif kind == 14:
                length = self.word(p + 4)
                if length > (self.end - p - 8) // 8:
                    raise ValueError("invalid relocation block")
                for i in range(length):
                    put(out, dst + 8 + i * 8, self.location(self.word(p + 8 + i * 8)))
                    put(
                        out,
                        dst + 12 + i * 8,
                        self.location(self.word(p + 12 + i * 8), True),
                    )
            else:
                raise ValueError("internal list error")
            put(out, dst, head)
            head = dst
            p = nextp
        return head


def combine(paths):
    if not 1 <= len(paths) <= 256:
        raise ValueError("expected 1 to 256 objects")
    objects = []
    totals = [0] * 11
    starts = [0] * 11
    props = [0] * 11
    heads = [0] * 15
    for path in paths:
        try:
            o = Object(path)
        except (ValueError, OSError) as e:
            raise ValueError(f"{path}: {e}") from e
        objects.append(o)
        for a in range(1, 11):
            o.base[a] = align(totals[a], 8)
            totals[a] = add(o.base[a], o.length[a])
            props[a] |= o.props[a]
    cursor = 32
    for a in (1, 10, 4, 6, 2, 5, 7, 8, 9):
        totals[a] = align(totals[a], 8)
        starts[a] = cursor
        cursor = add(cursor, totals[a])
    amap = cursor
    ldata = add(amap, 124)
    cursor = add(ldata, 60)
    for o in objects:
        if cursor < o.metadata:
            cursor = align(o.metadata, 4)
        o.delta = cursor - o.metadata
        cursor = align(add(cursor, o.end - o.metadata), 4)
    end = cursor
    physical = align(end, 4096)
    out = bytearray(physical)
    for p, n in (
        (0, end),
        (4, 32),
        (8, physical),
        (12, 1),
        (24, ldata),
        (28, amap),
        (amap, 10),
        (ldata, 14),
    ):
        put(out, p, n)
    for a in range(1, 11):
        for off, n in ((4, starts[a]), (8, totals[a]), (12, props[a])):
            put(out, amap + off + (a - 1) * 12, n)
    for o in objects:
        for a in range(1, 11):
            if o.length[a]:
                dest = starts[a] + o.base[a]
                out[dest : dest + o.length[a]] = o.data[
                    o.start[a] : o.start[a] + o.length[a]
                ]
        out[o.metadata + o.delta : o.end + o.delta] = o.data[o.metadata : o.end]
        for kind in (1, 4, 7, 8, 9, 14):
            heads[kind] = o.copy_list(out, kind, heads[kind])
        print(f"{o.path} code={o.base[1]:06x} gla={o.base[2]:06x}")
    for i in range(1, 15):
        put(out, ldata + i * 4, heads[i])
    return out


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("output", type=Path)
    parser.add_argument("inputs", type=Path, nargs="+")
    args = parser.parse_args()
    try:
        data = combine(args.inputs)
        args.output.write_bytes(data)
    except (ValueError, OSError) as error:
        parser.exit(1, f"{error}\n")
    print(
        f"Combined {len(args.inputs)} objects; {len(data)} bytes. Symbol resolution is deferred to IFIX."
    )


if __name__ == "__main__":
    main()
