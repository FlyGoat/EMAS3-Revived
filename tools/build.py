# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Jiaxun Yang <jiaxun.yang@flygoat.com>

"""Build the hosted IMP compiler and its EMAS compatibility library."""

import argparse
import os
import subprocess
from pathlib import Path

from ximplang.api import CompileOptions, compile_file, parse
from ximplang.codegen import Variable, evaluate
from ximplang.driver import build_runtime
from ximplang.target import Target

import ximplang

ROOT = Path(__file__).resolve().parents[1]
RUNTIME_INCLUDE = Path(ximplang.__file__).parent / "runtime"


def host_definitions(target):
    source = ROOT / "src/compilers/ercc07/hostcodes.imp"
    constants = {}
    for node in parse(source.read_text(), filename=str(source)):
        constants[node.name] = Variable(
            node.type, constant=evaluate(node.initial[0][0], constants)
        )
    host_mask = (1 << constants["emas"].constant) | (1 << constants["amdahl"].constant)
    features = {
        "lintavail": True,
        "llrealavail": False,
        "ieeefpformat": True,
        "ibmfpformat": False,
        "vaxfpformat": False,
        "emachine": False,
        "wordswopped": target.little_endian,
        "halfswopped": target.little_endian,
    }
    # Preserve the archived host and guest selections; change representation only.
    return [
        "XIMPLHOST=1",
        *[
            f"{name}={(constants[name].constant & ~host_mask) | (host_mask if enabled else 0)}"
            for name, enabled in features.items()
        ],
    ]


def compiler(target):
    sources = (
        ("src/compilers/ercc07/ibmponeas.imp", "src/compilers/ercc07/poneb02s.imp"),
        (
            "src/compilers/ercc07/trimp_ibmoptions.imp",
            "src/compilers/ercc07/trimp_ibmptwoas.imp",
            "src/compilers/ercc07/timp06s.imp",
        ),
        ("src/compilers/ercc07/trimp_ibmoptas.imp", "src/compilers/ercc07/opt04s.imp"),
        ("src/compilers/ercc07/ibmgen05s.imp",),
        ("src/compilers/ercc07/cserv01s.imp",),
        ("src/compilers/ercc07/host_put.imp",),
        ("src/xautils/ibmrecos.imp",),
    )
    aliases = {
        "ercc07.trimp_hostcodes": "src/compilers/ercc07/hostcodes.imp",
        "ercc07:itrimp_hostcodes": "src/compilers/ercc07/hostcodes.imp",
        "ercc07:itrimp_tform2s": "src/compilers/ercc07/host_tform2s.imp",
        "ercc07:tripcnsts": "src/compilers/ercc07/tripcnsts.imp",
        "ercc07:putspecs": "src/compilers/ercc07/host_putspecs.imp",
        "xautils_ctoptxa": "src/compilers/ercc07/ctoptnass.imp",
        "ercc07:ibmsup_seguse2": "src/supervisor/ibmsup/seguse2.imp",
        "ercc10:opouts": "src/compilers/ercc10/opouts.imp",
        **{
            f"ercs20:ib7_{name}": f"src/compilers/ercc07/ib7_{name}.imp"
            for name in ("mnemonics", "props", "names")
        },
    }
    aliases = {name: str(ROOT / path) for name, path in aliases.items()}
    options = CompileOptions(
        target=target.triple, include_aliases=aliases, defines=host_definitions(target)
    )
    directory = ROOT / "build/host/compiler"
    directory.mkdir(parents=True, exist_ok=True)
    for unit in sources:
        stem = Path(unit[-1]).stem
        wrapper = directory / f"{stem}.imp"
        wrapper.write_text("".join(f'%include "{ROOT / source}"\n' for source in unit))
        obj = directory / f"{stem}.o"
        obj.write_bytes(compile_file(wrapper, options).emit())
        print(obj.relative_to(ROOT), flush=True)


def compat(directory, target, cc):
    directory.mkdir(parents=True, exist_ok=True)
    options = CompileOptions(target=target.triple, include_dirs=[RUNTIME_INCLUDE])
    objects = []
    for module in ("emas_compat", "services", "adapters", "host_addresses"):
        obj = directory / f"{module}.o"
        obj.write_bytes(
            compile_file(ROOT / "host" / f"{module}.imp", options).emit(optimization=2)
        )
        objects.append(obj)
    archive = directory / "libemascompat.a"
    archive.unlink(missing_ok=True)
    subprocess.run(
        [os.environ.get("LLVM_AR", "llvm-ar"), "rcsD", archive, *objects], check=True
    )
    build_runtime(directory / "runtime", target, clang=cc)
    print(archive)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    compiler_parser = commands.add_parser("compiler")
    compiler_parser.add_argument("--target")
    compat_parser = commands.add_parser("compat")
    compat_parser.add_argument("directory", type=Path)
    compat_parser.add_argument("--target")
    compat_parser.add_argument("--cc", default="clang")
    args = parser.parse_args()
    target = Target.get(args.target)
    if args.command == "compiler":
        compiler(target)
    else:
        compat(args.directory, target, args.cc)


if __name__ == "__main__":
    main()
