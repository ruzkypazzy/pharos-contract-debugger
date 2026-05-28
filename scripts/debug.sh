#!/bin/bash

# Pharos Contract Debugger - Live Transaction Analyzer
# Network: Pharos Pacific Ocean Mainnet (Chain ID: 1672)

RPC_URL="https://rpc.pharos.xyz"
EXPLORER="https://pharosscan.xyz/tx"

if [ -z "$1" ]; then
  echo "Usage: bash scripts/debug.sh <TX_HASH>"
  echo "Example: bash scripts/debug.sh 0xabc123..."
  exit 1
fi

TX_HASH=$1

echo ""
echo "🔍 Pharos Contract Debugger"
echo "================================"
echo "Network: Pharos Pacific Ocean Mainnet"
echo "Chain ID: 1672"
echo "TX: $TX_HASH"
echo ""

# Step 1: Get transaction receipt
echo "📡 Fetching transaction from mainnet..."
RECEIPT=$(curl -s -X POST "$RPC_URL" \
  -H "Content-Type: application/json" \
  -d "{\"jsonrpc\":\"2.0\",\"method\":\"eth_getTransactionReceipt\",\"params\":[\"$TX_HASH\"],\"id\":1}")

# Step 2: Check if tx exists
if echo "$RECEIPT" | grep -q '"result":null'; then
  echo "❌ Transaction not found on Pharos mainnet."
  echo "   Check the hash or make sure it was submitted to Chain ID 1672."
  exit 1
fi

# Step 3: Get status
STATUS=$(echo "$RECEIPT" | grep -o '"status":"0x[01]"' | grep -o '0x[01]')
GAS_USED=$(echo "$RECEIPT" | grep -o '"gasUsed":"0x[^"]*"' | grep -o '0x[^"]*')
BLOCK=$(echo "$RECEIPT" | grep -o '"blockNumber":"0x[^"]*"' | grep -o '0x[^"]*')
TO=$(echo "$RECEIPT" | grep -o '"to":"0x[^"]*"' | head -1 | grep -o '0x[^"]*')

# Convert hex gas to decimal
GAS_DEC=$(printf "%d" "$GAS_USED" 2>/dev/null || echo "unknown")
BLOCK_DEC=$(printf "%d" "$BLOCK" 2>/dev/null || echo "unknown")

echo "📊 TRANSACTION DETAILS"
echo "----------------------"
echo "Block:     $BLOCK_DEC"
echo "Gas Used:  $GAS_DEC"
echo "Contract:  $TO"
echo ""

# Step 4: Get full transaction for gas limit
TX=$(curl -s -X POST "$RPC_URL" \
  -H "Content-Type: application/json" \
  -d "{\"jsonrpc\":\"2.0\",\"method\":\"eth_getTransactionByHash\",\"params\":[\"$TX_HASH\"],\"id\":1}")

GAS_LIMIT=$(echo "$TX" | grep -o '"gas":"0x[^"]*"' | grep -o '0x[^"]*')
GAS_LIMIT_DEC=$(printf "%d" "$GAS_LIMIT" 2>/dev/null || echo "unknown")

# Step 5: Diagnose
if [ "$STATUS" = "0x1" ]; then
  echo "✅ STATUS: SUCCESS"
  echo "   Transaction executed successfully."
  echo "   Gas Used: $GAS_DEC / $GAS_LIMIT_DEC"
else
  echo "❌ STATUS: FAILED"
  echo ""
  echo "🔎 DIAGNOSIS"
  echo "------------"

  # Check out of gas
  if [ "$GAS_DEC" = "$GAS_LIMIT_DEC" ]; then
    echo "🚨 CAUSE: OUT OF GAS"
    echo "   Gas used ($GAS_DEC) equals gas limit ($GAS_LIMIT_DEC)."
    echo "   FIX: Increase gas limit by at least 20% when sending."
  else
    echo "⚠️  CAUSE: TRANSACTION REVERTED"
    echo "   Gas Used: $GAS_DEC / $GAS_LIMIT_DEC"
    echo ""
    echo "   Common causes on Pharos:"
    echo "   • Insufficient token balance or allowance"
    echo "   • Access control / missing role"
    echo "   • Slippage exceeded on DEX swap"
    echo "   • Contract paused or not initialized"
    echo "   • Wrong function arguments"
  fi
fi

echo ""
echo "🔗 View on Explorer: $EXPLORER/$TX_HASH"
echo "📡 Network: Pharos Pacific Ocean Mainnet (Chain ID: 1672)"
