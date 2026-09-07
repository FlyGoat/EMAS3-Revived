# EMAS3 revived

EMAS3 for IBM XA, bootstrapped from [Edinburgh Computer History Project Archives](https://history.dcs.ed.ac.uk/) sources to run on Hercules.

Using [ximplang](https://github.com/FlyGoat/ximplang) to compile the original IMP compiler, with the EMAS3 itself being built by the original IMP compiler and utils.

## Run a release with Hercules

Install Hercules Hyperion and a TN3270 terminal client. Download
`emas3-revived.tar.gz` from the [GitHub releases](https://github.com/FlyGoat/EMAS3-Revived/releases).
The archive contains initialized boot and system disks plus `hercules.cnf`;
no compilation or disk provisioning is needed.

Extract it into a new directory and start Hercules from that directory so the
configuration can find the disks:

```sh
hercules -f hercules.cnf
```

1. Connect your TN3270 terminal to `127.0.0.1:3272`.
2. Enter `ipl 150` at the Hercules console.
3. Once the loader is ready, enter `SLOAD 0 64` in the TN3270 guest terminal.

To shut down, enter `D/CLOSEDOWN` in the guest terminal, wait for closedown to
finish, then enter `quit` at the Hercules console.

The current release starts the supervisor, Director, spooler and mailer.
Full startup and an interactive guest IMP environment are not yet available.
See [running EMAS](docs/running.md) for further console instructions.

## System build

The maintained system sources are in `src/supervisor`, `src/chopsupe`,
`src/director`, `src/subsystem` and the executive directories. These contain
the archive's newer revisions. Compiler sources and shared opcode tables are
under `src/compilers`; the EMAS host library and IMP build wrappers are in `host`.

Build the system components:

```sh
make supervisor-image loader-image director-image executive-images
```

The end-to-end workflow compiles the system, fixes and stages its images,
provisions disks, then starts EMAS in Hercules through the console tools.
All image fixers, including `subfix`, run through the shared native IMP tool
`build/fixers/fix-image`, with IBM byte order handled at the host file boundary.
Install Hercules separately. The tools use `hercules` and `dasdinit` from PATH, or the executable
paths set by `HERCULES` and `DASDINIT`:

```sh
export HERCULES=/path/to/hercules
export DASDINIT=/path/to/dasdinit
```

See [building](docs/build.md) and [running EMAS](docs/running.md) for the
complete setup and console instructions.

## License

Historical EMAS sources and files derived from them retain their historical
licensing terms.

All other files are licensed under the [MIT License](LICENSE).
