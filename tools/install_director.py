#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Jiaxun Yang <jiaxun.yang@flygoat.com>

"""Build the Director image and install it on an offline EMAS volume."""

import argparse
import struct
import subprocess
from pathlib import Path

from write_emas_pages import stage

ROOT = Path(__file__).resolve().parents[1]


def install(object_path, disk_path, *, replace=False, output_directory=None):
    output_directory = Path(output_directory or ROOT / "build/director")
    output_directory.mkdir(parents=True, exist_ok=True)
    output = output_directory / "ERCC04:DIRECTOR"
    subprocess.run(
        [ROOT / "build/fixers/fix-image", "director", object_path, output], check=True
    )
    data = output.read_bytes()
    if not data or len(data) % 4096 or len(data) > 128 * 4096:
        raise ValueError("Director must occupy 1 to 128 whole pages")
    pages, first, label = stage(
        disk_path, 512, data, system_area=True, expected_label="EMAS00", replace=replace
    )
    print(f"Installed {pages} pages at {first} on {label}")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("object", type=Path)
    parser.add_argument("disk", type=Path)
    parser.add_argument("--replace", action="store_true")
    parser.add_argument("--output-directory", type=Path)
    args = parser.parse_args()
    try:
        install(
            args.object,
            args.disk,
            replace=args.replace,
            output_directory=args.output_directory,
        )
    except (OSError, ValueError, KeyError, struct.error, subprocess.CalledProcessError) as error:
        parser.exit(1, f"Director installation failed: {error}\n")


if __name__ == "__main__":
    main()
