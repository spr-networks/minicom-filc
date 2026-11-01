# Minicom built with Fil-C

This repository builds Minicom 2.12-dev for Linux x86_64 (`amd64` in Docker) and ARM64 using [Fil-C](https://fil-c.org/). Each build also compiles ncurses with Fil-C because Fil-C has a separate ABI from ordinary system libraries. The build uses Fil-C 0.687, ncurses 6.6, and the exact Minicom source snapshot in [`sources/`](sources/README.md). All inputs are checked against pinned SHA-256 digests.

GitHub Actions builds both architectures on native Linux runners after each push to `main`, or when started manually. Each run uploads a tarball containing Minicom, `runscript`, `ascii-xfr`, the matching Fil-C runtime libraries, license texts, the Minicom source archive, and this README. CI checks that Minicom starts and loads ncurses and the Fil-C runtime from `/opt/filc/pizfix/lib`. The tarballs also have SHA-256 checksum files and GitHub build provenance attestations. See the [Actions builds](https://github.com/spr-networks/minicom-filc/actions/workflows/build.yml) for downloads.

To build locally with Docker:

```sh
./build.sh arm64
./build.sh amd64
./package.sh arm64
./package.sh amd64
```

The resulting images are `minicom-filc:linux-arm64` and `minicom-filc:linux-amd64`. Local tarballs are in `dist/`. On a Linux machine of the matching architecture, extract a tarball to a temporary directory and copy its `opt/filc` tree to `/opt/filc`.

Minicom is configured without NLS or lockdev and uses `/var/lock` for lock files. Serial-device behavior still needs testing with real hardware. ARM64 support in Fil-C is [experimental](https://fil-c.org/install_optfil).
