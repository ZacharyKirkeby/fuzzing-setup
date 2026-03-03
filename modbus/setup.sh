#!/usr/bin/env bash
set -e

WORKDIR="$HOME/fuzz/libmodbus"
LIBMODBUS_VERSION="v3.1.12"
SEED_DIR="$PWD/in"

if [ ! -d "$SEED_DIR" ]; then
  echo "[!] Seed directory ./in not found."
  exit 1
fi

if [ -z "$(ls -A "$SEED_DIR")" ]; then
  echo "[!] ./in exists but is empty."
  exit 1
fi

echo "[+] Installing dependencies..."
sudo pacman -Syu --noconfirm
sudo pacman -S --noconfirm \
  base-devel git cmake make autoconf automake libtool pkgconf \
  afl++ llvm clang gdb strace ltrace tcpdump

echo "[+] Creating workspace..."
mkdir -p "$WORKDIR"
cd "$WORKDIR"

echo "[+] Cloning AFLNet..."
if [ ! -d aflnet ]; then
  git clone https://github.com/aflnet/aflnet.git
  cd aflnet
  make clean all
  sudo make install
  cd ..
fi

echo "[+] Cloning libmodbus..."
if [ ! -d libmodbus ]; then
  git clone https://github.com/stephane/libmodbus.git
fi

cd libmodbus
git fetch --all
git checkout "$LIBMODBUS_VERSION"

echo "[+] Building libmodbus with AFL instrumentation..."
export CC=afl-clang-fast
export CXX=afl-clang-fast++
export CFLAGS="-O1 -g -fsanitize=address -fno-omit-frame-pointer"

./autogen.sh
./configure --disable-shared
make -j"$(nproc)"

cd tests
make
cd "$WORKDIR"

echo "[+] Creating Modbus dictionary..."
cat <<EOF > modbus.dict
"read_coils"="\x01"
"read_discrete"="\x02"
"read_holding"="\x03"
"read_input"="\x04"
"write_single_coil"="\x05"
"write_single_reg"="\x06"
"write_multiple_coils"="\x0F"
"write_multiple_regs"="\x10"
EOF

echo "[+] Adjusting system settings for fuzzing..."
echo core | sudo tee /proc/sys/kernel/core_pattern
echo 0 | sudo tee /proc/sys/kernel/randomize_va_space
ulimit -c unlimited

echo "[+] Setup complete."
echo "Run ./fuzz.sh to begin fuzzing."
