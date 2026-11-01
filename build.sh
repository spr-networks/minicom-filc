#!/bin/sh
set -eu

repo_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
source_archive="$repo_dir/sources/minicom-master.tar.gz"
cache_dir="$repo_dir/.cache"
output_dir="$repo_dir/build"
filc_version=0.687
ncurses_version=6.6
ncurses_sha=355b4cbbed880b0381a04c46617b7656e362585d52e9cf84a67e2009b749ff11
minicom_sha=f046c1029df82fa18f2da6093cd4ffeecb49fb6339d5fd00b6956bccf603af45

mkdir -p "$cache_dir" "$output_dir"
test -f "$source_archive" || { echo "Missing $source_archive" >&2; exit 1; }

check_sha() {
    digest=$1 path=$2
    if command -v sha256sum >/dev/null 2>&1; then
        printf '%s  %s\n' "$digest" "$path" | sha256sum -c -
    else
        printf '%s  %s\n' "$digest" "$path" | shasum -a 256 -c -
    fi
}

check_sha "$minicom_sha" "$source_archive"

download() {
    url=$1 dest=$2 expected=$3
    if ! test -f "$dest" || ! check_sha "$expected" "$dest" >/dev/null 2>&1; then
        curl -fL --retry 3 -o "$dest.tmp" "$url"
        mv "$dest.tmp" "$dest"
    fi
    check_sha "$expected" "$dest"
}

download "https://ftp.gnu.org/gnu/ncurses/ncurses-$ncurses_version.tar.gz" \
    "$cache_dir/ncurses.tar.gz" "$ncurses_sha"

if test "$#" -eq 0; then
    set -- arm64 amd64
fi

for arch in "$@"; do
    case "$arch" in
        arm64) filc_arch=aarch64; filc_sha=f1337799051664f93c7712141deaebe78571ae96ffcf05563d517b89440bcbc0 ;;
        amd64) filc_arch=x86_64; filc_sha=aab538401f78a47ab261ee79afed8c6b99e1d4848e263ae159a75b03c1288da1 ;;
        *) echo "Architecture must be arm64 or amd64: $arch" >&2; exit 1 ;;
    esac
    download "https://github.com/pizlonator/fil-c/releases/download/v$filc_version/filc-$filc_version-linux-$filc_arch.tar.xz" \
        "$cache_dir/filc-$arch.tar.xz" "$filc_sha"
    context=$(mktemp -d)
    cp "$source_archive" "$context/minicom.tar.gz"
    cp "$cache_dir/ncurses.tar.gz" "$context/ncurses.tar.gz"
    cp "$cache_dir/filc-$arch.tar.xz" "$context/filc.tar.xz"
    cp "$repo_dir/Dockerfile" "$context/Dockerfile"
    image="minicom-filc:linux-$arch"
    mkdir -p "$output_dir/$arch"
    if docker build --progress=plain --platform "linux/$arch" \
        --build-arg FILC_SHA256="$filc_sha" \
        --build-arg NCURSES_SHA256="$ncurses_sha" \
        --build-arg MINICOM_SHA256="$minicom_sha" -t "$image" "$context" \
        >"$output_dir/$arch/build.log" 2>&1; then
        tail -8 "$output_dir/$arch/build.log"
    else
        tail -100 "$output_dir/$arch/build.log" >&2
        rm -rf "$context"
        exit 1
    fi
    rm -rf "$context"
    docker run --rm --platform "linux/$arch" "$image" minicom --version
    docker run --rm --platform "linux/$arch" "$image" minicom --help >/dev/null
    loader="/opt/filc/pizfix/lib/ld-fil1-$filc_arch.so"
    docker run --rm --platform "linux/$arch" --entrypoint "$loader" "$image" \
        --list /opt/filc/bin/minicom >"$output_dir/$arch/dependencies.txt"
    grep -F 'libncursesw.so.6 => /opt/filc/pizfix/lib/' "$output_dir/$arch/dependencies.txt"
    grep -F 'libpizlo.so => /opt/filc/pizfix/lib/' "$output_dir/$arch/dependencies.txt"
    container=$(docker create --platform "linux/$arch" "$image")
    docker cp "$container:/opt/filc/bin/." "$output_dir/$arch/"
    mkdir -p "$output_dir/$arch/pizfix"
    docker cp "$container:/opt/filc/pizfix/lib" "$output_dir/$arch/pizfix/"
    docker rm "$container" >/dev/null
    echo "Built $image and $output_dir/$arch"
done
