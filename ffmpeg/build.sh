#!/usr/bin/env bash
set -euo pipefail

ROOT="$PWD/ffmpeg-afl"
mkdir -p "$ROOT"
cd "$ROOT"

# ---------------------------------------------------------------------------
# Dependencies
# ---------------------------------------------------------------------------
echo "[*] Installing dependencies..."
sudo pacman -S --needed --noconfirm \
    base-devel \
    clang \
    lld \
    git \
    nasm \
    yasm \
    afl++ \
    zlib \
    bzip2 \
    xz

# ---------------------------------------------------------------------------
# Clone + checkout
# ---------------------------------------------------------------------------
echo "[*] Cloning FFmpeg..."
if [ ! -d FFmpeg ]; then
    git clone https://github.com/FFmpeg/FFmpeg.git
fi
cd FFmpeg
git checkout n6.1

# ---------------------------------------------------------------------------
# Build FFmpeg instrumented with AFL++ + ASan
#
# Key decisions:
#   - AFL_USE_ASAN=1 instruments the static libraries with ASan at compile
#     time. We do NOT also pass -fsanitize=address at link time — doing both
#     causes duplicate runtime init and potential symbol conflicts.
#   - --disable-stripping + -g + -fno-omit-frame-pointer keep stack traces
#     symbolised so ASan reports are actually readable.
#   - Decoders are enabled so avformat_find_stream_info can fully exercise
#     the demuxer's packet-reading paths; without them it exits early.
#   - libswresample is built because avformat pulls it in transitively;
#     omitting it causes undefined-symbol linker errors.
# ---------------------------------------------------------------------------
echo "[*] Cleaning..."
make distclean 2>/dev/null || true

export CC=afl-clang-fast
export CXX=afl-clang-fast++
export AFL_USE_ASAN=1

echo "[*] Configuring AFL++ build..."
./configure \
    --disable-everything \
    \
    --enable-demuxer=matroska \
    \
    --enable-decoder=vorbis,opus,aac,mp3,flac,av1,vp8,vp9,h264,hevc \
    \
    --enable-parser=h264,hevc,vp8,vp9,av1,aac,mp3,opus,vorbis \
    \
    --enable-bsf=null \
    \
    --enable-protocol=pipe \
    \
    --disable-network \
    --disable-doc \
    --disable-programs \
    --disable-asm \
    --disable-hwaccels \
    --disable-vaapi \
    --disable-vdpau \
    --disable-vulkan \
    --disable-cuda \
    --disable-cuvid \
    --disable-nvenc \
    --disable-d3d11va \
    --disable-dxva2 \
    \
    --enable-static \
    --disable-shared \
    \
    --disable-stripping \
    --extra-cflags="-g -fno-omit-frame-pointer" \
    --enable-small

make -j"$(nproc)"

# ---------------------------------------------------------------------------
# Build the fuzz harness
#
# Link order matters for static archives: higher-level libs first.
# Do NOT add -fsanitize=address here — AFL_USE_ASAN=1 already handled it
# during the FFmpeg build and afl-clang-fast propagates it at link time.
# ---------------------------------------------------------------------------
cd ..

echo "[*] Copying target.c..."
if [ ! -f ../target2.c ]; then
    echo "[-] target2.c not found in parent directory"
    exit 1
fi
cp ../target2.c .

echo "[*] Building harness..."
afl-clang-fast \
    -g -fno-omit-frame-pointer \
    target2.c \
    FFmpeg/libavformat/libavformat.a \
    FFmpeg/libavcodec/libavcodec.a \
    FFmpeg/libswresample/libswresample.a \
    FFmpeg/libavutil/libavutil.a \
    -lz -lbz2 -llzma -lm \
    -o fuzz_target

echo "[+] Build complete. Binary: $ROOT/fuzz_target"
