#!/usr/bin/env bash
set -euo pipefail

ROOT="$PWD/ffmpeg-afl"

if [ ! -f "$ROOT/fuzz_target" ]; then
  echo "[-] fuzz_target not found. Run build_env.sh first."
  exit 1
fi

echo "[*] Checking instrumentation..."
afl-showmap -o /dev/null -- "$ROOT/fuzz_target" /dev/null || true

echo "[*] Checking ASan..."
ASAN_OPTIONS=detect_leaks=0 "$ROOT/fuzz_target" /dev/null || true

echo "[+] Environment ready."
echo
echo "Run fuzzing with:"
echo "cd ffmpeg-afl"
echo "afl-fuzz -i seeds -o out -m none -- ./fuzz_target @@"
