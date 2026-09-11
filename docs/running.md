<!--
SPDX-License-Identifier: MIT
Copyright (c) 2026 Jiaxun Yang <jiaxun.yang@flygoat.com>
-->

# Run EMAS3

First [build the images](build.md). The commands below run from the repository
root and use the installed Hercules executable selected by `HERCULES`.

## Launch from the build directory

The image and disk targets copy the configuration to `build/ipl/hercules.cnf`.
With disks in that directory, launch Hercules there:

```sh
cd build/ipl
HERCULES_RC=/dev/null "${HERCULES:-hercules}" -f hercules.cnf
```

Connect a TN3270 terminal to `127.0.0.1:3271`, then enter `ipl 150` at the
Hercules console. To create initialized system disks, follow the installation
steps below from the repository root.

## Create a new installation

```sh
.venv/bin/python tools/provision_disks.py build/emas
```

Choose a directory that does not already exist. The script creates and formats
two disks, installs the system images, initializes the filesystems, and restarts
the guest. It starts and stops Hercules automatically. Allow several minutes.

The console uses port 3272. Use `--port NUMBER` if that port is occupied.
A failed run leaves its disks and logs in place; use a new directory to try
again. Do not reuse these formatting commands on a disk you want to keep.

The resulting directory contains:

- `hercules.cnf`: configuration for this installation.
- `chop.3380`, `emas0.3380`, `emas1.3380`: the boot and system disks.
- `*.log`, `*.txt`, `*-printer.txt`: emulator, console and printer output.

Provisioning installs the subsystem basefile and creates ERCC01 and SUBSYS.
It installs the IMP compiler in `SUBSYS:IMP` and registers it in `SUBSYS:BASEDIR`.
It verifies an ERCC01 session and file persistence across a reboot. REMOTE, INFORM
and PADOUT remain disabled. MAILER's site configuration and directory files
are not supplied, so it reports missing files and stays closed; this does not
prevent subsystem login or SPOOLR operation.

## Start an existing installation

```sh
HERCULES_RC=/dev/null "${HERCULES:-hercules}" -f build/emas/hercules.cnf
```

Connect a TN3270 terminal to `127.0.0.1:3272`, or the port selected during
provisioning. Enter `ipl 150` at the Hercules console. Once the loader is ready,
enter `SLOAD 0 64` in the guest terminal to load the supervisor.

For a user session, enter `D/NEWSTART ERCC01` at `COMMAND:`. At the
`Command: from NUMBER` prompt, try `SSVSN` and `FILES`, then `LOGOFF` to return
to the operator console. This uses the privileged TN3270 operator console.

To create a small IMP source file, start a fresh user session and enter each
line below at the command prompt:

```text
QUEUE "%begin"
QUEUE 'printstring("Hello from IMP"); newline'
QUEUE "%endofprogram"
COPY T#STACK,HELLOS
IMP HELLOS,HELLOO
RUN HELLOO
```

`QUEUE` appends each quoted source line to the session's temporary stack file.
`COPY` saves it as `HELLOS`; `IMP` compiles it to `HELLOO`, and `RUN` prints
`Hello from IMP`. Use a fresh session so the stack contains only these lines.

To shut down, enter `D/CLOSEDOWN` in the guest terminal and wait for closedown
to finish before entering `quit` at the Hercules console.

## Run console commands from a script

With no other Hercules process using these disks:

```sh
.venv/bin/python tools/run_chop.py \
  --config build/emas/hercules.cnf --port 3272 \
  --log-directory build/emas --name session \
  --wait 3 --command-wait 10 \
  --command 'SLOAD 0 64' --command 'D/CLOSEDOWN'
```

This starts Hercules, boots the loader, sends the commands and stops the
emulator. Output is saved as `session.log` and `session.txt`. Increase
`--wait` for a slower initial boot or `--command-wait` for longer guest commands.

## Update installed images

Stop Hercules and back up the disks before replacing system images. Rebuild
the images, then update the supervisor and Director:

```sh
.venv/bin/python tools/write_emas_pages.py \
  build/emas/emas0.3380 64 build/supervisor/isup-fixed --system-area --replace
SOURCE_DATE_EPOCH=0 .venv/bin/python tools/install_director.py \
  build/director/combined build/emas/emas0.3380 --replace
```

The page writer refuses to overwrite different data unless `--replace` is
supplied. Updating an image does not require reformatting the filesystem.
