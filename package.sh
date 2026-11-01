#!/bin/sh
set -eu

repo_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
test "$#" -eq 1 || { echo "Usage: $0 arm64|amd64" >&2; exit 1; }
arch=$1
case "$arch" in
    arm64) filc_arch=aarch64 ;;
    amd64) filc_arch=x86_64 ;;
    *) echo "Unsupported architecture: $arch" >&2; exit 1 ;;
esac

build_dir="$repo_dir/build/$arch"
for name in minicom runscript ascii-xfr; do
    test -x "$build_dir/$name" || { echo "Missing $build_dir/$name" >&2; exit 1; }
done
test -d "$build_dir/pizfix/lib" || { echo "Missing Fil-C runtime libraries" >&2; exit 1; }

stage=$(mktemp -d)
trap 'rm -rf "$stage"' EXIT HUP INT TERM
mkdir -p "$stage/opt/filc/bin" "$stage/opt/filc/pizfix" \
    "$stage/sources" "$stage/licenses" "$repo_dir/dist"
cp "$build_dir/minicom" "$build_dir/runscript" "$build_dir/ascii-xfr" "$stage/opt/filc/bin/"
cp -R "$build_dir/pizfix/lib" "$stage/opt/filc/pizfix/"
cp "$repo_dir/sources/minicom-master.tar.gz" "$stage/sources/"
cp "$repo_dir/README.md" "$stage/"
tar -xOzf "$repo_dir/sources/minicom-master.tar.gz" minicom-master/COPYING \
    >"$stage/licenses/MINICOM-COPYING"
tar -xOzf "$repo_dir/.cache/ncurses.tar.gz" ncurses-6.6/COPYING \
    >"$stage/licenses/NCURSES-COPYING"
for name in MUSL-LICENSE.txt LLVM-LICENSE.txt PAS-LICENSE.txt; do
    tar -xOJf "$repo_dir/.cache/filc-$arch.tar.xz" \
        "filc-0.687-linux-$filc_arch/$name" >"$stage/licenses/$name"
done

archive="$repo_dir/dist/minicom-filc-linux-$arch.tar.gz"
if tar --version 2>/dev/null | grep -q 'GNU tar'; then
    tar --owner=0 --group=0 --numeric-owner -C "$stage" -czf "$archive" \
        README.md licenses opt sources
else
    tar --uid 0 --gid 0 --uname root --gname root -C "$stage" -czf "$archive" \
        README.md licenses opt sources
fi
if command -v sha256sum >/dev/null 2>&1; then
    (cd "$repo_dir/dist" && sha256sum "$(basename "$archive")" >"$(basename "$archive").sha256")
else
    (cd "$repo_dir/dist" && shasum -a 256 "$(basename "$archive")" >"$(basename "$archive").sha256")
fi
echo "Packaged $archive"
