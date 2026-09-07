#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Jiaxun Yang <jiaxun.yang@flygoat.com>

"""Boot CHOPSUPE, send console commands through tnz, and save session logs."""

import argparse
import math
import os
import shutil
import socket
import subprocess
import time
from pathlib import Path

from tnz_console import Console

ROOT = Path(__file__).resolve().parents[1]


def executable(variable, default):
    path = shutil.which(os.environ.get(variable, default))
    if path is None:
        raise FileNotFoundError(
            f"{default} not found; set {variable} or add it to PATH"
        )
    return str(Path(path).resolve())


def check_port(port):
    if not 1 <= port <= 65535:
        raise ValueError("console port must be between 1 and 65535")
    with socket.socket() as probe:
        probe.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        probe.bind(("127.0.0.1", port))


def stop(process, inspections):
    try:
        if process.poll() is None:
            commands = ["stop", "psw", "gpr", *inspections, "quit", ""]
            process.communicate("\n".join(commands), timeout=5)
        else:
            process.communicate()
    finally:
        if process.poll() is None:
            process.kill()
            process.communicate()


def run_session(
    *,
    config=ROOT / "build/ipl/hercules.cnf",
    log_directory=ROOT / "build/ipl",
    name="chop-session",
    port=3271,
    commands=(),
    wait=2,
    command_wait=None,
    expected=(),
    breakpoint=None,
    inspections=(),
    screen_callback=None,
):
    if command_wait is None:
        command_wait = wait
    if any(not math.isfinite(value) or value < 0 for value in (wait, command_wait)):
        raise ValueError("wait times must be finite and nonnegative")
    if Path(name).name != name or name in ("", ".", ".."):
        raise ValueError("name must be a plain file basename")
    if any("\n" in command or "\r" in command for command in (*commands, *inspections)):
        raise ValueError("each command must be a single line")
    if breakpoint is not None and not 0 <= breakpoint <= 0xFFFFFFFF:
        raise ValueError("breakpoint must be a 32-bit address")
    config = Path(config).resolve()
    if not config.is_file():
        raise FileNotFoundError(f"missing Hercules configuration: {config}")
    hercules = executable("HERCULES", "hercules")
    check_port(port)
    directory = Path(log_directory).resolve()
    directory.mkdir(parents=True, exist_ok=True)
    screens = []
    with (directory / f"{name}.log").open("w") as log:
        process = subprocess.Popen(
            [hercules, "-f", str(config)],
            cwd=config.parent,
            env={**os.environ, "HERCULES_RC": "/dev/null"},
            stdin=subprocess.PIPE,
            stdout=log,
            stderr=subprocess.STDOUT,
            text=True,
        )
        console = None
        try:
            deadline = time.monotonic() + 5
            while True:
                if process.poll() is not None:
                    raise RuntimeError(
                        f"Hercules exited; see {directory / f'{name}.log'}"
                    )
                try:
                    console = Console(port=port)
                    break
                except ConnectionRefusedError:
                    if time.monotonic() >= deadline:
                        raise
                    time.sleep(0.05)
            console.receive(0.5)
            if breakpoint is not None:
                process.stdin.write(f"b {breakpoint:X}\n")
            process.stdin.write("ipl 150\n")
            process.stdin.flush()
            console.receive(wait)
            screens.append("IPL\n" + console.text())
            if screen_callback is not None:
                screen_callback("IPL", console.text())
            for command in commands:
                console.enter(command)
                console.receive(command_wait)
                screens.append(command + "\n" + console.text())
                if screen_callback is not None:
                    screen_callback(command, console.text())
        finally:
            try:
                if console is not None:
                    console.close()
            finally:
                try:
                    stop(process, inspections)
                finally:
                    (directory / f"{name}.txt").write_text("\n\n".join(screens))
    output = "\n\n".join(screens)
    for text in expected:
        if text not in output:
            raise ValueError(
                f"expected console text absent: {text}; see {directory / f'{name}.txt'}"
            )
    return output


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--command", action="append", default=[])
    parser.add_argument("--wait", type=float, default=2)
    parser.add_argument("--command-wait", type=float)
    parser.add_argument("--name", default="chop-session")
    parser.add_argument("--expect", action="append", default=[])
    parser.add_argument("--breakpoint", type=lambda value: int(value, 16))
    parser.add_argument(
        "--config", type=Path, default=ROOT / "build/ipl/hercules.cnf"
    )
    parser.add_argument("--log-directory", type=Path, default=ROOT / "build/ipl")
    parser.add_argument("--port", type=int, default=3271)
    parser.add_argument(
        "--inspect",
        action="append",
        default=[],
        help="Hercules monitor command after stopping the CPU; repeat as needed",
    )
    args = parser.parse_args()
    try:
        print(
            run_session(
                config=args.config,
                log_directory=args.log_directory,
                name=args.name,
                port=args.port,
                commands=args.command,
                wait=args.wait,
                command_wait=args.command_wait,
                expected=args.expect,
                breakpoint=args.breakpoint,
                inspections=args.inspect,
            )
        )
    except (OSError, ValueError, RuntimeError, subprocess.SubprocessError) as error:
        parser.exit(1, f"CHOPSUPE: {error}\n")


if __name__ == "__main__":
    main()
