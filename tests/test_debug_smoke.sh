#!/bin/bash
# Smoke test for pharos-contract-debugger.
# Verifies debug.sh runs end-to-end and produces expected output sections.

set -e

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEBUG="$REPO_ROOT/scripts/debug.sh"

if [ ! -x "$DEBUG" ]; then
  echo "❌ scripts/debug.sh not found or not executable"
  exit 1
fi

# Sample public mainnet tx (revert case)
SAMPLE_TX="0x9606bcfd027b28e6783ca8b5fef1c3311476a1c30e5bf4464d0340a0d24ba7f7"

echo "🧪 Running smoke test against $SAMPLE_TX"
echo ""

# Run the script, capture output
OUT=$(bash "$DEBUG" "$SAMPLE_TX" --network mainnet 2>&1)
RC=$?

if [ $RC -ne 0 ] && [ $RC -ne 1 ]; then
  echo "❌ debug.sh exited with unexpected code $RC"
  echo "$OUT" | head -20
  exit 1
fi

# Verify the output contains the expected sections
for SECTION in "Pharos Contract Debugger" "Network:" "TX:" "STATUS" "Block" "Gas"; do
  if ! echo "$OUT" | grep -qiF "$SECTION"; then
    echo "❌ expected section not found: $SECTION"
    echo "$OUT" | head -30
    exit 1
  fi
done

echo "✅ All required sections present in output"
echo ""
echo "Output preview:"
echo "$OUT" | head -25

# Test: should fail gracefully when given a bogus tx hash
echo ""
echo "🧪 Testing graceful failure on bogus hash..."
OUT2=$(bash "$DEBUG" "0x0000000000000000000000000000000000000000000000000000000000000000" --network mainnet 2>&1 || true)
if ! echo "$OUT2" | grep -qi "not found"; then
  echo "❌ expected 'not found' for bogus hash, got:"
  echo "$OUT2"
  exit 1
fi
echo "✅ Bogus hash handled gracefully"

# Test: --help works
echo ""
echo "🧪 Testing --help..."
HELP=$(bash "$DEBUG" --help 2>&1)
if ! echo "$HELP" | grep -qi "Usage:"; then
  echo "❌ --help didn't print usage"
  exit 1
fi
echo "✅ --help works"

echo ""
echo "🎉 All smoke tests passed."
