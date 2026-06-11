#!/bin/bash
# Smoke test: verify the script fails gracefully when cast is missing,
# and that the arg parser works. Live RPC test requires Foundry installed.
set -e

SCRIPT="scripts/debug.sh"

# Test 1: help flag
bash "$SCRIPT" --help >/dev/null

# Test 2: missing arg
if bash "$SCRIPT" 2>&1 | grep -q "Usage"; then
  echo "OK: missing arg shows usage"
else
  echo "FAIL: missing arg did not show usage"
  exit 1
fi

# Test 3: unknown flag
if bash "$SCRIPT" --foo 2>&1 | grep -q "Unknown flag"; then
  echo "OK: unknown flag rejected"
else
  echo "FAIL: unknown flag not rejected"
  exit 1
fi

# Test 4: bad network
if bash "$SCRIPT" 0xabc --network bogus 2>&1 | grep -q "Unknown network"; then
  echo "OK: bad network rejected"
else
  echo "FAIL: bad network not rejected"
  exit 1
fi

# Test 5: cast missing (if cast not installed, should fail with the right message)
if ! command -v cast >/dev/null 2>&1; then
  if bash "$SCRIPT" 0xabc --network mainnet 2>&1 | grep -q "cast.*not found"; then
    echo "OK: cast-missing error is clear"
  else
    echo "FAIL: cast-missing error unclear"
    exit 1
  fi
else
  # Cast installed - try a real (failed) tx to verify the script runs end-to-end
  if bash "$SCRIPT" 0x9606bcfd027b28e6783ca8b5fef1c3311476a1c30e5bf4464d0340a0d24ba7f7 --network mainnet 2>&1 | grep -qE "STATUS: (SUCCESS|FAILED)"; then
    echo "OK: live cast read worked"
  else
    echo "FAIL: live cast read did not produce a diagnosis"
    exit 1
  fi
fi

echo ""
echo "All smoke tests passed."
