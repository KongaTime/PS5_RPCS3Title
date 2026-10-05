#!/usr/bin/env bash
# RPCS3 for the PS5 - FFmpeg for the console, as static archives.
#
#   rpcs3/build-ffmpeg.sh     build it once into .deps/native/ffmpeg-ps5 (lib/, include/)
#
# RPCS3 decodes the PS3's video and audio (cellVdec, cellAdec, movies, ATRAC)
# with FFmpeg. Upstream links RPCS3/ffmpeg-core's prebuilt archives, which have
# no build for this console, so this builds the same release from FFmpeg's
# source at a pinned commit, with the components ffmpeg-core enables
# (3rdparty/ffmpeg/ffmpeg.patch in RPCS3): everything else disabled, no network,
# no programs or docs. Software decoding only.
#
# The source comes from FFmpeg's GitHub mirror (the tag's commit is the check);
# NASM is the host's (nasm 2.16 or later).
#
# Copyright (C) 2026 KongaTime
# SPDX-License-Identifier: MIT

set -euo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
sdk=$root/.deps/native/ps5-payload-sdk
prefix=$root/.deps/native/ffmpeg-ps5
build=$root/build/ffmpeg-ps5

tag=n8.1.1
revision=239f2c733de417201d7ad3b3b8b0d9b63285b2b1   # FFmpeg n8.1.1, as RPCS3's ffmpeg-core
stamp="$revision $(sha256sum "$0" | cut -c1-64)"
[[ -f $prefix/.stamp && $(<"$prefix/.stamp") == "$stamp" ]] && {
    echo "==> [ffmpeg] $tag already built in $prefix"; exit 0; }

[[ -x $sdk/bin/prospero-clang ]] || {
    echo "error: no payload SDK in $sdk: run ps5/tools/setup-sdk.sh" >&2; exit 1; }
nasm=$(command -v nasm) || { echo "error: FFmpeg's x86 code needs nasm on the host" >&2; exit 1; }

src=$root/.deps/ffmpeg-src
if [[ $(git -C "$src" rev-parse HEAD 2>/dev/null) != "$revision" ]]; then
    echo "==> [ffmpeg] fetching $tag"
    rm -rf -- "$src"
    git -c advice.detachedHead=false clone --quiet --depth 1 --branch "$tag" https://github.com/FFmpeg/FFmpeg.git "$src"
    [[ $(git -C "$src" rev-parse HEAD) == "$revision" ]] || {
        echo "error: FFmpeg's $tag is not at $revision" >&2; exit 1; }
fi

rm -rf -- "$build"
mkdir -p "$build/empty-libs"
# FFmpeg links -lm; the math functions are the console's own libc.
"$sdk/bin/prospero-ar" rc "$build/empty-libs/libm.a"

# ffmpeg-core's components (RPCS3's 3rdparty/ffmpeg/ffmpeg.patch)
components=(
    --enable-decoder=aac --enable-decoder=aac_latm --enable-decoder=atrac3
    --enable-decoder=atrac3p --enable-decoder=atrac9 --enable-decoder=mp3
    --enable-decoder=pcm_s16le --enable-decoder=pcm_s8
    --enable-decoder=mov --enable-decoder=h264 --enable-decoder=mpeg4
    --enable-decoder=mpeg2video --enable-decoder=mjpeg --enable-decoder=mjpegb
    --enable-encoder=pcm_s16le --enable-encoder=mp3 --enable-encoder=ac3 --enable-encoder=aac
    --enable-encoder=ffv1 --enable-encoder=mpeg4 --enable-encoder=mjpeg --enable-encoder=h264
    --enable-muxer=avi --enable-muxer=h264 --enable-muxer=mjpeg --enable-muxer=mp4
    --enable-demuxer=h264 --enable-demuxer=m4v --enable-demuxer=mp3 --enable-demuxer=mpegvideo
    --enable-demuxer=mpegps --enable-demuxer=mjpeg --enable-demuxer=mov
    --enable-demuxer=avi --enable-demuxer=aac --enable-demuxer=pmp --enable-demuxer=oma
    --enable-demuxer=pcm_s16le --enable-demuxer=pcm_s8 --enable-demuxer=wav
    --enable-parser=h264 --enable-parser=mpeg4video --enable-parser=mpegaudio
    --enable-parser=mpegvideo --enable-parser=mjpeg --enable-parser=aac --enable-parser=aac_latm
    --enable-protocol=file
    --enable-bsf=mjpeg2jpeg
)

echo "==> [ffmpeg] configuring $tag (Zen 2, static)"
(cd "$build" && "$src/configure" --prefix="$prefix" \
    --enable-cross-compile --target-os=freebsd --arch=x86_64 --cpu=znver2 \
    --cc="$sdk/bin/prospero-clang" --cxx="$sdk/bin/prospero-clang++" \
    --ar="$sdk/bin/prospero-ar" --ranlib="$sdk/bin/prospero-ranlib" --nm="$sdk/bin/prospero-nm" \
    --x86asmexe="$nasm" --pkg-config=false \
    --enable-static --disable-shared --enable-pic --disable-programs --disable-doc \
    --disable-debug --disable-autodetect --disable-avdevice --disable-avfilter \
    --disable-everything --disable-network "${components[@]}" \
    --extra-cflags="-fno-omit-frame-pointer" --extra-ldflags="-L$build/empty-libs" \
    >"$build/configure.log" 2>&1) || {
    tail -30 "$build/ffbuild/config.log" >&2; echo "error: configure failed: $build/configure.log" >&2; exit 1; }

echo "==> [ffmpeg] building"
make -C "$build" -j"$(nproc)" >"$build/make.log" 2>&1 || {
    tail -30 "$build/make.log" >&2; exit 1; }
rm -rf -- "$prefix"
make -C "$build" install >"$build/install.log" 2>&1
printf '%s\n' "$stamp" >"$prefix/.stamp"
echo "==> [ffmpeg] $tag: $(du -sh "$prefix/lib" | cut -f1) of archives in $prefix"
