#!/usr/bin/env bash
# RPCS3 for the PS5 - GNU libiconv for the console, as a static archive.
#
#   rpcs3/build-libiconv.sh     build it once into .deps/native/libiconv-ps5 (lib/, include/)
#
# RPCS3's cellL10n converts the PS3's text encodings (Shift-JIS, EUC-JP, the
# ISO-8859 family, UTF-8/16/32 and more) with iconv, which the console's libc
# does not have. This builds GNU libiconv (LGPL-2.1-or-later) from GNU's
# release tarball, checked against its SHA-256.
#
# Copyright (C) 2026 KongaTime
# SPDX-License-Identifier: MIT

set -euo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
sdk=$root/.deps/native/ps5-payload-sdk
prefix=$root/.deps/native/libiconv-ps5
build=$root/build/libiconv-ps5

version=1.18
digest=3b08f5f4f9b4eb82f151a7040bfd6fe6c6fb922efe4b1659c66ea933276965e8
stamp="$version $(sha256sum "$0" | cut -c1-64)"
[[ -f $prefix/.stamp && $(<"$prefix/.stamp") == "$stamp" ]] && {
    echo "==> [libiconv] $version already built in $prefix"; exit 0; }

[[ -x $sdk/bin/prospero-clang ]] || {
    echo "error: no payload SDK in $sdk: run ps5/tools/setup-sdk.sh" >&2; exit 1; }

archive=$root/.deps/downloads/libiconv-$version.tar.gz
mkdir -p "$root/.deps/downloads"
[[ -f $archive ]] || curl --fail --location --retry 3 --silent --show-error \
    "https://ftp.gnu.org/pub/gnu/libiconv/libiconv-$version.tar.gz" -o "$archive"
printf '%s  %s\n' "$digest" "$archive" | sha256sum --check --status || {
    echo "error: libiconv's archive does not match its SHA-256" >&2; exit 1; }

rm -rf -- "$build"
mkdir -p "$build/src"
tar -xzf "$archive" -C "$build/src" --strip-components=1

echo "==> [libiconv] configuring $version (Zen 2, static)"
(cd "$build/src" && ./configure --host=x86_64-unknown-freebsd14 --prefix="$prefix" \
    --disable-shared --enable-static --disable-nls \
    CC="$sdk/bin/prospero-clang" AR="$sdk/bin/prospero-ar" RANLIB="$sdk/bin/prospero-ranlib" \
    CFLAGS="-O2 -march=znver2 -fno-omit-frame-pointer -fPIC" \
    >"$build/configure.log" 2>&1) || {
    tail -30 "$build/configure.log" >&2; echo "error: configure failed: $build/configure.log" >&2; exit 1; }

echo "==> [libiconv] building"
# Only the library, after the libcharset header the top-level Makefile installs
# into lib/ first; the iconv program is not needed
(make -C "$build/src" lib/localcharset.h && make -C "$build/src/lib" -j"$(nproc)") \
    >"$build/make.log" 2>&1 || {
    tail -30 "$build/make.log" >&2; exit 1; }
rm -rf -- "$prefix"
mkdir -p "$prefix/lib" "$prefix/include"
cp "$build/src/lib/.libs/libiconv.a" "$prefix/lib/"
cp "$build/src/include/iconv.h" "$prefix/include/"
printf '%s\n' "$stamp" >"$prefix/.stamp"
echo "==> [libiconv] $version in $prefix"
