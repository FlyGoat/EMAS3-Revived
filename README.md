# EMAS3 revived

EMAS3 for IBM XA, bootstrapped from [Edinburgh Computer History Project Archives](https://history.dcs.ed.ac.uk/) sources to run on Hercules.

Using [ximplang](https://github.com/FlyGoat/ximplang) to compile the original IMP compiler, with the EMAS3 itself being built by the original IMP compiler and utils.

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
Image fixing runs directly in Python using IBM byte order. Install Hercules
separately. The tools use `hercules` and `dasdinit` from PATH, or the executable
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
