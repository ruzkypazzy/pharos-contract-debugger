#!/bin/bash

RPC_URL="https://rpc.pharos.xyz"
TX_HASH="0x9606bcfd027b28e6783ca8b5fef1c3311476a1c30e5bf4464d0340a0d24ba7f7"

echo ""
echo "======================================"
echo "  PHAROS CONTRACT DEBUGGER - DEMO"
echo "======================================"
echo ""
echo "STEP 1: Checking transaction on Pharos mainnet..."
echo "TX: $TX_HASH"
echo ""

STATUS=$(cast receipt $TX_HASH --rpc-url $RPC_URL --json | jq -r '.status')
GAS_USED=$(cast receipt $TX_HASH --rpc-url $RPC_URL --json | jq -r '.gasUsed')
FROM=$(cast receipt $TX_HASH --rpc-url $RPC_URL --json | jq -r '.from')
TO=$(cast receipt $TX_HASH --rpc-url $RPC_URL --json | jq -r '.to')

echo "--------------------------------------"
echo " Sender:      $FROM"
echo " Contract:    $TO"
echo " Gas Used:    $((16#${GAS_USED#0x})) units"
echo "--------------------------------------"
echo ""

if [ "$STATUS" = "0x0" ]; then
  echo "RESULT: ❌ TRANSACTION FAILED"
  echo ""
  echo "STEP 2: Decoding the error..."
  ERROR=$(cast receipt $TX_HASH --rpc-url $RPC_URL --json | jq -r '.revertReason' | grep -o '0x[a-f0-9]*')
  DECODED=$(cast 4byte $ERROR 2>/dev/null)
  echo ""
  echo "--------------------------------------"
  echo " Error Code:  $ERROR"
  echo " Decoded:     $DECODED"
  echo "--------------------------------------"
  echo ""
  echo "STEP 3: Diagnosis & Fix"
  echo ""
  echo " The transaction failed because:"
  echo " → $DECODED"
  echo ""
  echo " What this means:"
  echo " The contract rejected this transaction because"
  echo " the operation did not generate enough profit."
  echo " This is common in DEX swaps with minimum"
  echo " profit requirements."
  echo ""
  echo " HOW TO FIX:"
  echo " • Adjust slippage tolerance"
  echo " • Reduce minimum profit threshold"
  echo " • Try again when market conditions improve"
else
  echo "RESULT: ✅ TRANSACTION SUCCESSFUL"
fi

echo ""
echo " Explorer: https://pharosscan.xyz/tx/$TX_HASH"
echo " Network:  Pharos Pacific Ocean Mainnet (Chain ID: 1672)"
echo "======================================"
