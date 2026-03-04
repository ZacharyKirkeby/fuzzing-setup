#!/usr/bin/env bash
set -euo pipefail

ROOT="$PWD/ffmpeg-afl"
BINARY="$ROOT/fuzz_target"
SEEDS="$PWD/seeds_min"
DICT="$PWD/matroska.dict"
OUT="$ROOT/out"

# ---------------------------------------------------------------------------
# Pre checks
# ---------------------------------------------------------------------------
if [ ! -f "$BINARY" ]; then
    echo "[-] fuzz_target not found. Run build_env.sh first."
    exit 1
fi

if [ ! -f "$DICT" ]; then
    echo "[-] Dictionary not found at $DICT"
    exit 1
fi

if [ ! -d "$SEEDS" ] || [ -z "$(ls -A "$SEEDS")" ]; then
    echo "[-] Seed directory '$SEEDS' is missing or empty."
    exit 1
fi

mkdir -p "$OUT"

# ---------------------------------------------------------------------------
# Verify instrumentation and ASan linkage
# ---------------------------------------------------------------------------
echo "[*] Checking binary is executable..."
if [ ! -x "$BINARY" ]; then
    echo "[-] Binary is not executable: $BINARY"
    exit 1
fi

echo "[*] Checking AFL++ instrumentation and ASan linkage..."
ASAN_OPTIONS=detect_leaks=0:abort_on_error=1 \
    echo -n "RIFF" | afl-showmap -o /dev/null -q -t 5000 -- "$BINARY" 2>/dev/null || true

echo "[+] Preflight OK."
echo

# ---------------------------------------------------------------------------
# Tune the kernel for AFL++ (requires root; skip with SKIP_TUNE=1 if needed)
# ---------------------------------------------------------------------------
if [ "${SKIP_TUNE:-0}" != "1" ]; then
    echo "[*] Applying kernel performance tuning..."
    echo core | sudo tee /proc/sys/kernel/core_pattern > /dev/null
    echo performance | sudo tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor > /dev/null 2>&1 || true
fi

# ---------------------------------------------------------------------------
# Run AFL++
#
# flags:
#   -m none        Required with ASan — ASan's large mappings confuse AFL's
#                  default memory limit and cause spurious OOM kills.
#   -t 5000        5-second per-execution timeout; Matroska parsing can be
#                  slow on adversarial inputs, so the default 1s is too tight.
#   NO @@          The harness uses __AFL_FUZZ_TESTCASE_BUF (shared-memory
#                  persistent mode). Input is fed via shmem, not argv. Passing
#                  @@ would make AFL++ write a file that the harness never reads.
#
# ASAN_OPTIONS:
#   detect_leaks=0          LSan inside AFL++ causes false-positive aborts.
#   abort_on_error=1        Turn ASan findings into crashes AFL++ can catch.
#   symbolize=1             Human-readable stack traces in crash reports.
# ---------------------------------------------------------------------------
echo "[*] Starting AFL++ fuzzer..."
echo "    Seeds : $SEEDS"
echo "    Output: $OUT"
echo "    Binary: $BINARY"
echo

ASAN_OPTIONS=detect_leaks=0:abort_on_error=1:symbolize=1 \
    afl-fuzz \
        -i "$SEEDS" \
        -o "$OUT" \
        -m none \
        -t 5000 \
        -x "$DICT" \
        -- "$BINARY"
