#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Jiaxun Yang <jiaxun.yang@flygoat.com>

"""Stage page-aligned files into an offline, guest-formatted EMAS CKD volume."""

import argparse
import errno
import os
from pathlib import Path

from ckd import CKD


def stage(
    disk_path, page, data, *, system_area=False, replace=False, expected_label=None
):
    if not data or len(data) % 4096 or not 0 <= page <= 0xFFFFFF:
        raise ValueError(
            "input must contain whole 4096-byte pages and page must be nonnegative"
        )
    pages = len(data) // 4096
    with CKD(disk_path, writable=True) as disk:
        name, cylinders, per_track, sbase, base = disk.emas_label()
        if expected_label is not None and name != expected_label:
            raise ValueError(f"expected volume {expected_label}, found {name}")
        first = page + (sbase if system_area else base)
        if (
            system_area and (base <= 64 or page + pages > base)
        ) or first + pages > cylinders * disk.heads * per_track:
            raise ValueError("pages outside selected area")
        writes = []
        for i in range(pages):
            offset, old = disk.page(first + i, per_track)
            new = data[i * 4096 : (i + 1) * 4096]
            if not replace and old != new and any(old):
                raise FileExistsError(
                    errno.EEXIST,
                    f"page {first + i} contains different data; use --replace explicitly",
                )
            writes.append((offset, new))
        for offset, new in writes:
            disk.file.seek(offset)
            if disk.file.write(new) != len(new):
                raise OSError("short CKD write")
        disk.file.flush()
        os.fsync(disk.file.fileno())
        for offset, new in writes:
            disk.file.seek(offset)
            if disk.file.read(len(new)) != new:
                raise OSError("CKD read-back differs")
    return pages, first, name


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("disk", type=Path)
    parser.add_argument("page", type=lambda s: int(s, 0))
    parser.add_argument("input", type=Path)
    parser.add_argument("--system-area", action="store_true")
    parser.add_argument("--replace", action="store_true")
    args = parser.parse_args()
    try:
        pages, first, name = stage(
            args.disk,
            args.page,
            args.input.read_bytes(),
            system_area=args.system_area,
            replace=args.replace,
        )
    except (ValueError, OSError) as error:
        parser.exit(1, f"{error}\n")
    print(f"Verified {pages} pages at physical page {first}, volume {name}")


if __name__ == "__main__":
    main()
