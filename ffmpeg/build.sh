#!/usr/bin/env bash
set -euo pipefail

ROOT="$PWD/ffmpeg-afl"
mkdir -p "$ROOT"
cd "$ROOT"

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

echo "[*] Cloning FFmpeg..."
if [ ! -d FFmpeg ]; then
  git clone https://github.com/FFmpeg/FFmpeg.git
fi

cd FFmpeg
git checkout n6.1

echo "[*] Cleaning..."
make distclean || true

echo "[*] Configuring AFL++ build..."
CC=afl-clang-fast \
CXX=afl-clang-fast++ \
./configure \
  --disable-everything \
  --enable-demuxer=matroska \
  --enable-protocol=file \
  --disable-network \
  --disable-pthreads \
  --disable-doc \
  --disable-programs \
  --disable-asm \
  --enable-static \
  --disable-shared \
  --disable-debug \
  --enable-small

make -j$(nproc)

cd ..

echo "[*] Copying target.c..."
if [ ! -f ../target.c ]; then
  echo "[-] target.c not found in parent directory"
  exit 1
fi

cp ../target.c .

echo "[*] Building harness..."
afl-clang-fast -fsanitize=address \
  target.c \
  FFmpeg/libavformat/libavformat.a \
  FFmpeg/libavcodec/libavcodec.a \
  FFmpeg/libavutil/libavutil.a \
  -lz -lbz2 -llzma -lm \
  -o fuzz_target

echo "[+] Build complete."
echo "Binary: $ROOT/fuzz_target"
