#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Jiaxun Yang <jiaxun.yang@flygoat.com>

"""Stage XACFIX's IPL blocks into an existing raw 3380 image."""

import argparse
import fcntl
import os
import struct
from pathlib import Path


def stage(source, disk):
    data = source.read_bytes()
    if len(data) < 32:
        raise ValueError("missing ICHOPT header")
    end, start, size = struct.unpack_from(">III", data)
    if (
        start != 4096
        or end != size
        or not 16384 <= end <= 1024 * 1024
        or end % 4096
        or len(data) < end
    ):
        raise ValueError("invalid ICHOPT file bounds")
    pages = (end - start) // 4096
    tracks = (pages + 9) // 10
    with disk.open("r+b") as f:
        fcntl.lockf(f, fcntl.LOCK_EX | fcntl.LOCK_NB)
        header = f.read(512)
        if (
            len(header) != 512
            or header[:8] != b"CKD_P370"
            or header[16:18] != b"\x80\0"
        ):
            raise ValueError("expected single-file uncompressed Hercules 3380 image")
        heads, tracksize = struct.unpack_from("<II", header, 8)
        if not heads or not 5 + 16 + 10 * (8 + 4096) + 8 <= tracksize <= 1024 * 1024:
            raise ValueError("invalid geometry")
        if tracks > heads:
            raise ValueError("IPL blocks exceed one cylinder")
        if os.fstat(f.fileno()).st_size < 512 + tracks * tracksize:
            raise ValueError("disk image too short")
        images = []
        page = 0
        for head in range(tracks):
            track = bytearray(tracksize)
            struct.pack_into(">BHH", track, 0, 0, 0, head)
            struct.pack_into(">HHBBH", track, 5, 0, head, 0, 0, 8)
            p = 21
            for record in range(1, 11):
                struct.pack_into(">HHBBH", track, p, 0, head, record, 0, 4096)
                p += 8
                if page < pages:
                    track[p : p + 4096] = data[
                        start + page * 4096 : start + (page + 1) * 4096
                    ]
                page += 1
                p += 4096
            track[p : p + 8] = b"\xff" * 8
            images.append(track)
        for head, track in enumerate(images):
            f.seek(512 + head * tracksize)
            if f.write(track) != tracksize:
                raise OSError("short track write")
        f.flush()
        os.fsync(f.fileno())
        for head, track in enumerate(images):
            f.seek(512 + head * tracksize)
            if f.read(tracksize) != track:
                raise OSError("track read-back differs")
    print(
        f"Staged {pages} IPL blocks on {tracks} tracks. No EMAS filesystem is present."
    )


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("source", type=Path)
    p.add_argument("disk", type=Path)
    a = p.parse_args()
    try:
        stage(a.source, a.disk)
    except (ValueError, OSError) as e:
        p.exit(1, f"chop-ipl-disk: {e}\n")


if __name__ == "__main__":
    main()
