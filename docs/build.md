<!--
SPDX-License-Identifier: MIT
Copyright (c) 2026 Jiaxun Yang <jiaxun.yang@flygoat.com>
-->

# Build EMAS3

Run these commands from the repository root on Linux. You'll need Python 3.12
or later, `uv`, Clang, `llvm-ar`, and GNU Make 4.3 or later. Install Hercules Hyperion
separately, including its `dasdinit` utility.

```sh
uv venv
uv pip install -r requirements.txt
```

If Hercules is not on PATH, set the executable paths:

```sh
export HERCULES=/path/to/hercules
export DASDINIT=/path/to/dasdinit
```

Build the compiler, system images and IPL disk:

```sh
make system-images chop-ipl-disk
```

Make uses `.venv` without requiring activation. ximplang is installed from
GitHub through `requirements.txt`. Targets rebuild when their inputs change;
rerunning the same command leaves current outputs alone.

The outputs are:

| File | Purpose |
| --- | --- |
| `build/host/emas-imp` | Hosted IMP compiler |
| `build/ipl/chop.3380` | Boot disk containing the loader |
| `build/supervisor/isup-fixed` | Supervisor image |
| `build/director/ERCC04:DIRECTOR` | Director image |
| `build/executives/ivolums` | Volume manager image |
| `build/executives/ispoolr` | Spooler image |
| `build/executives/imailer` | Mailer image |
| `build/executives/iftrans` | File-transfer image |
| `build/fixers/fix-image` | Shared tool for all archived IMP image fixers |
| `build/subsystem/basefile` | Interactive subsystem with built-in command aliases |

`make host-driver` builds the hosted compiler. To compile your own
IMP source to an IBM object file, use:

```sh
build/host/emas-imp input.imp output
```

Compilation logs are beside the system objects under `build/supervisor`,
`build/chopsupe`, `build/director` and `build/executives`.

The image fixers run the archived `ifix8s.imp`, `xacfix01s.imp`, `c02bld.imp`,
`vsmfix1s.imp` and `subfix.imp` through ximplang. `XIMPLP64` widens host
addresses while retaining 32-bit guest words. The IMP file adapters convert IBM
byte order at the boundary and preserve strings, code and IPL byte records.
Director's unused call-table string padding is cleared for reproducible output.
Python still handles object combination, disk packaging and provisioning.

`make image-fixers` builds the shared native fixer tool. The subsystem command
also takes the Director image that supplies its system-call table:

```sh
build/fixers/fix-image subsystem build/subsystem/combined \
  build/subsystem/basefile build/director/ERCC04:DIRECTOR
```

Next, [create the disks and start EMAS](running.md).

## Automated builds

GitHub Actions builds on pushes to `main`, pull requests, and tags. Each run
uploads an `emas3-revived` artifact containing `emas3-revived.tar.gz`: the boot
disk, two initialized system disks, and `hercules.cnf`. Extract the archive and
run `HERCULES_RC=/dev/null hercules -f hercules.cnf` from that directory. The terminal
port is 3272.

Pushing a tag also attaches the archive to a GitHub Release. Rerunning a tag
build replaces the archive on its existing release.
