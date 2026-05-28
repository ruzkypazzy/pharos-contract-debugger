#!/bin/bash

RPC_URL="https://rpc.pharos.xyz"

# Use provided tx hash or fall back to demo
if [ -z "$1" ]; then
  echo ""
  echo "No tx hash provided. Using demo transaction..."
  TX_HASH="0x9606bcfd027b28e6783ca8b5fef1c3311476a1c30e5bf4464d0340a0d24ba7f7"
else
  TX_HASH=$1
fi

echo ""
echo "======================================"
echo "  PHAROS CONTRACT DEBUGGER"
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

if [ "$STATUS" = "0x1" ]; then
  echo "RESULT: ✅ TRANSACTION SUCCESSFUL"
  echo " This transaction completed without errors."
elif [ "$STATUS" = "0x0" ]; then
  echo "RESULT: ❌ TRANSACTION FAILED"
  echo ""
  echo "STEP 2: Decoding the error..."
  ERROR=$(cast receipt $TX_HASH --rpc-url $RPC_URL --json | jq -r '.revertReason' | grep -o '0x[a-f0-9]*')
  
  if [ -z "$ERROR" ]; then
    GAS_LIMIT=$(cast tx $TX_HASH --rpc-url $RPC_URL --json | jq -r '.gas')
    GAS_LIMIT_DEC=$((16#${GAS_LIMIT#0x}))
    GAS_USED_DEC=$((16#${GAS_USED#0x}))
    echo ""
    if [ "$GAS_USED_DEC" -ge "$GAS_LIMIT_DEC" ]; then
      echo "--------------------------------------"
      echo " Cause:   OUT OF GAS"
      echo " Fix:     Increase gas limit by 20-30%"
      echo "--------------------------------------"
    else
      echo "--------------------------------------"
      echo " Cause:   TRANSACTION REVERTED"
      echo " Reason:  No error code returned"
      echo "--------------------------------------"
    fi
  else
    DECODED=$(cast 4byte $ERROR 2>/dev/null)
    echo ""
    echo "--------------------------------------"
    echo " Error Code:  $ERROR"
    echo " Decoded:     $DECODED"
    echo "--------------------------------------"
    echo ""
    echo "STEP 3: Diagnosis & Fix"
    echo ""
    echo " The transaction failed because: $DECODED"
  fi
else
  echo "RESULT: ⚠️ TRANSACTION NOT FOUND"
  echo " Check the hash or confirm it was sent to Chain ID 1672"
fi

echo ""
echo " Explorer: https://pharosscan.xyz/tx/$TX_HASH"
echo " Network:  Pharos Pacific Ocean Mainnet (Chain ID: 1672)"
echo "======================================"
