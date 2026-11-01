FROM ubuntu:24.04 AS builder

ARG TARGETARCH
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y --no-install-recommends \
    autoconf automake autopoint build-essential ca-certificates file gettext \
    linux-libc-dev make ncurses-bin patchelf pkg-config xz-utils && \
    rm -rf /var/lib/apt/lists/*

COPY filc.tar.xz ncurses.tar.gz minicom.tar.gz /tmp/
ARG FILC_SHA256
ARG NCURSES_SHA256
ARG MINICOM_SHA256
RUN printf '%s  %s\n' "$FILC_SHA256" /tmp/filc.tar.xz \
      "$NCURSES_SHA256" /tmp/ncurses.tar.gz \
      "$MINICOM_SHA256" /tmp/minicom.tar.gz | sha256sum -c -

RUN mkdir -p /opt/filc /work/ncurses /work/minicom /work/build && \
    tar -xJf /tmp/filc.tar.xz -C /opt/filc --strip-components=1 && \
    tar -xzf /tmp/ncurses.tar.gz -C /work/ncurses --strip-components=1 && \
    tar -xzf /tmp/minicom.tar.gz -C /work/minicom --strip-components=1 && \
    cd /opt/filc && ./setup.sh

# Build the curses library with Fil-C as well; host libraries have a different ABI.
WORKDIR /work/ncurses
RUN CC=/opt/filc/build/bin/clang ./configure \
    --prefix=/opt/filc/pizfix --with-build-cc=gcc \
    --enable-widec --with-shared --without-debug --without-ada \
    --without-tests --without-progs --without-manpages \
    --with-default-terminfo-dir=/usr/share/terminfo && \
    make -j2 && make install.libs install.includes

WORKDIR /work/build
RUN if [ "$TARGETARCH" = arm64 ]; then \
        ln -sfn /usr/include/aarch64-linux-gnu/asm /opt/filc/pizfix/os-include/asm; \
    fi && \
    (cd /work/minicom && ./autogen.sh) && \
    NCURSES_CFLAGS='-I/opt/filc/pizfix/include/ncursesw' \
    NCURSES_LIBS='-lncursesw' \
    /work/minicom/configure CC=/opt/filc/build/bin/clang \
    CFLAGS='-O2 -g' --disable-nls --disable-lockdev \
    --enable-lock-dir=/var/lock --prefix=/opt/filc && \
    make -j2 && \
    if [ "$TARGETARCH" = arm64 ]; then loader=ld-fil1-aarch64.so; \
    else loader=ld-fil1-x86_64.so; fi && \
    for binary in src/minicom src/runscript src/ascii-xfr; do \
        patchelf --set-interpreter "/opt/filc/pizfix/lib/$loader" "$binary"; \
        patchelf --set-rpath /opt/filc/pizfix/lib "$binary"; \
    done

FROM ubuntu:24.04
ARG TARGETARCH
RUN apt-get update && apt-get install -y --no-install-recommends ncurses-base && \
    rm -rf /var/lib/apt/lists/*
COPY --from=builder /opt/filc/pizfix/lib/libyoloc.so /opt/filc/pizfix/lib/libc.so /opt/filc/pizfix/lib/libpizlo.so /opt/filc/pizfix/lib/libncursesw.so.6.6 /opt/filc/pizfix/lib/
RUN ln -s libncursesw.so.6.6 /opt/filc/pizfix/lib/libncursesw.so.6 && \
    if [ "$TARGETARCH" = arm64 ]; then loader=ld-fil1-aarch64.so; \
    else loader=ld-fil1-x86_64.so; fi && \
    ln -s libyoloc.so "/opt/filc/pizfix/lib/$loader"
COPY --from=builder /work/build/src/minicom /opt/filc/bin/minicom
COPY --from=builder /work/build/src/runscript /opt/filc/bin/runscript
COPY --from=builder /work/build/src/ascii-xfr /opt/filc/bin/ascii-xfr
ENV PATH=/opt/filc/bin:$PATH
CMD ["minicom", "--help"]
