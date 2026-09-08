#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Jiaxun Yang <jiaxun.yang@flygoat.com>

"""Create and initialize a new EMAS disk pair using Hercules and tnz."""

import argparse
import shutil
import subprocess
from datetime import datetime, timezone
from pathlib import Path

from ckd import CKD
from run_chop import check_port, executable, run_session
from write_emas_pages import stage

ROOT = Path(__file__).resolve().parents[1]
IMAGES = {
    "supervisor": (64, "build/supervisor/isup-fixed"),
    "director": (512, "build/director/ERCC04:DIRECTOR"),
    "volums": (1024, "build/executives/ivolums"),
    "spoolr": (1152, "build/executives/ispoolr"),
    "mailer": (1280, "build/executives/imailer"),
}


def configure(directory, port):
    text = (ROOT / "config/hercules-chop.cnf").read_text()
    for filename in ("chop.3380", "emas0.3380", "emas1.3380", "operator-printer.txt"):
        text = text.replace(filename, f'"{directory / filename}"')
    text = text.replace("127.0.0.1:3271", f"127.0.0.1:{port}")
    text = text.replace(
        "YROFFSET -38", f"YROFFSET {1988 - datetime.now(timezone.utc).year}"
    )
    config = directory / "hercules.cnf"
    config.write_text(text)
    return config


def provision(directory, port):
    directory = directory.resolve()
    if directory.exists():
        raise FileExistsError("destination already exists; choose a new directory")
    if any(character in str(directory) for character in ('"', "\n", "\r")):
        raise ValueError(
            "directory cannot contain quotes or newlines in Hercules configuration"
        )
    check_port(port)
    executable("HERCULES", "hercules")
    dasdinit = executable("DASDINIT", "dasdinit")
    inputs = {name: ROOT / relative for name, (_, relative) in IMAGES.items()}
    inputs["chop"] = ROOT / "build/ipl/chop.3380"
    for path in inputs.values():
        if not path.is_file():
            raise FileNotFoundError(f"missing build input: {path}")
    directory.mkdir(parents=True)
    shutil.copyfile(inputs["chop"], directory / "chop.3380")
    config = configure(directory, port)

    def console(name, commands, expected, wait):
        print(name, flush=True)
        try:
            run_session(
                config=config,
                log_directory=directory,
                name=name,
                port=port,
                commands=commands,
                expected=expected,
                wait=3,
                command_wait=wait,
            )
        finally:
            printer = directory / "operator-printer.txt"
            if printer.exists():
                shutil.copyfile(printer, directory / f"{name}-printer.txt")

    for disk in range(2):
        print(f"Creating disk {disk}", flush=True)
        path = directory / f"emas{disk}.3380"
        with (directory / f"create-{disk}.log").open("w") as log:
            subprocess.run(
                [dasdinit, "-r", str(path), "3380", "885"],
                stdout=log,
                stderr=subprocess.STDOUT,
                check=True,
            )
    for disk in range(2):
        path = directory / f"emas{disk}.3380"
        # ILABEL reserves 2048 pages for the system images.
        console(
            f"format-{disk}",
            [f"FORMAT FD8{disk} 0 884 0 14", f"ILABEL FD8{disk} EMAS0{disk}"],
            ["format complete", "labelled ok"],
            45,
        )
        with CKD(path) as volume:
            if volume.emas_label() != (f"EMAS0{disk}", 885, 10, 0, 2048):
                raise ValueError(f"unexpected label or geometry on disk {disk}")

    for name, (page, _) in IMAGES.items():
        print(f"Installing {name}", flush=True)
        stage(
            directory / "emas0.3380",
            page,
            inputs[name].read_bytes(),
            system_area=True,
            expected_label="EMAS00",
        )
    console(
        "initialize",
        ["SLOAD 0 64", "D/CLEARFSYS 0", "D/CLEARFSYS 1", "D/CLOSEDOWN"],
        ["FSYS 0 cleared OK", "FSYS 1 cleared OK"],
        10,
    )
    console(
        "mailer-files",
        ["SLOAD 0 64", "M/MAILLIST 0", "M/MAILLIST 1", "M/CREATE", "D/CLOSEDOWN"],
        ["NEW MAIL LIST FSYS 0", "NEW MAIL LIST FSYS 1", "ADDRFILE created"],
        8,
    )
    console(
        "restart",
        [
            "SLOAD 0 64",
            "D/NNT MAILER 0",
            "M/MAILLIST 0",
            "M/MAILLIST 1",
            "M/CREATE",
            "S/QUEUES",
            "S/STREAMS",
            "D/CLOSEDOWN",
        ],
        ["INDNO: 72", "Already open fsys 0", "Already open fsys 1", "Already exists",
         "All queues", "JOURNAL", "All streams", "LP0"],
        8,
    )
    print(f"Disks initialized: {directory}", flush=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("directory", type=Path, help="new directory; must not exist")
    parser.add_argument("--port", type=int, default=3272)
    args = parser.parse_args()
    try:
        provision(args.directory, args.port)
    except (OSError, ValueError, RuntimeError, subprocess.SubprocessError) as error:
        parser.exit(1, f"Provisioning failed: {error}\n")


if __name__ == "__main__":
    main()
