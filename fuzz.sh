#!/usr/bin/env bash
set -e

WORKDIR="$HOME/fuzz/libmodbus"
SEED_DIR="$PWD/in"
TARGET="$WORKDIR/libmodbus/tests/unit-test-server"

if [ ! -d "$SEED_DIR" ]; then
  echo "[!] Seed directory ./in not found."
  exit 1
fi

if [ ! -f "$TARGET" ]; then
  echo "[!] Target binary not found. Run setup.sh first."
  exit 1
fi

cd "$WORKDIR"

echo "[+] Starting AFLNet fuzzing using seeds from ./in"

AFL_NO_AFFINITY=1 \
AFL_SKIP_CPUFREQ=1 \
afl-fuzz -d \
  -i "$SEED_DIR" \
  -o findings \
  -N tcp \            # protocol
  -P 1502 \           # port number
  -q 3 \
  -s 3 \
  -D 10000 \
  -E \
  -K \
  -R \
  -x modbus.dict \
  -- "$TARGET" 127.0.0.1 1502  # pass the server args here
