# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Jiaxun Yang <jiaxun.yang@flygoat.com>

"""Raw Hercules CKD records; geometry comes from the image, not host layout."""

import fcntl
import struct


class CKD:
    def __init__(self, path, writable=False):
        self.file = open(path, "r+b" if writable else "rb")
        try:
            if writable:
                fcntl.lockf(self.file, fcntl.LOCK_EX | fcntl.LOCK_NB)
            header = self.file.read(512)
            if len(header) != 512 or header[:8] != b"CKD_P370" or header[17]:
                raise ValueError("expected single-file uncompressed CKD")
            self.heads, self.track_size = struct.unpack_from("<II", header, 8)
            if not self.heads or not 4096 <= self.track_size <= 1024 * 1024:
                raise ValueError("invalid CKD geometry")
        except BaseException:
            self.file.close()
            raise

    def __enter__(self):
        return self

    def __exit__(self, *args):
        self.file.close()

    def records(self, track):
        if track < 0:
            raise ValueError("negative track")
        offset = 512 + track * self.track_size
        self.file.seek(offset)
        data = self.file.read(self.track_size)
        cylinder, head = divmod(track, self.heads)
        if len(data) != self.track_size or data[:5] != struct.pack(
            ">BHH", 0, cylinder, head
        ):
            raise ValueError(f"invalid track header: {track}")
        records = {}
        pos = 5
        while pos + 8 <= len(data):
            if data[pos : pos + 8] == b"\xff" * 8:
                return records
            cc, hh, number, key, length = struct.unpack_from(">HHBBH", data, pos)
            if (
                (cc, hh) != (cylinder, head)
                or number in records
                or pos + 8 + key + length > len(data)
            ):
                raise ValueError(f"invalid record on track {track}")
            start = pos + 8
            records[number] = (
                offset + start + key,
                data[start : start + key],
                data[start + key : start + key + length],
            )
            pos = start + key + length
        raise ValueError(f"missing track terminator: {track}")

    def emas_label(self):
        records = self.records(0)
        _, key, label = records[0]
        if key or len(label) != 80 or label[10] != 0xC5:
            raise ValueError("volume is not labelled for EMAS")
        name = label[:6].decode("cp037")
        if not name[4:].isdigit():
            raise ValueError("invalid EMAS volume number")
        cylinders = struct.unpack_from(">H", label, 31)[0]
        heads = struct.unpack_from(">H", label, 35)[0]
        sbase, base = struct.unpack_from(">HH", label, 39)
        if heads != self.heads or not cylinders:
            raise ValueError("label geometry disagrees with CKD")
        pages = len(records) - 1
        if set(records) != set(range(pages + 1)) or any(
            key or len(data) != 4096 for _, key, data in list(records.values())[1:]
        ):
            raise ValueError("track zero does not contain sequential EMAS pages")
        return name, cylinders, pages, sbase, base

    def page(self, page, pages_per_track):
        track, record = divmod(page, pages_per_track)
        offset, key, data = self.records(track)[record + 1]
        if key or len(data) != 4096:
            raise ValueError(f"page {page} is not formatted as a 4096-byte record")
        return offset, data
