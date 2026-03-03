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
export CC=afl-clang-fast
export CXX=afl-clang-fast++
export AFL_USE_ASAN=1
echo "[*] Configuring AFL++ build..."
./configure \
  --disable-everything \
  --enable-demuxer=matroska \
  --enable-protocol=file \
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
