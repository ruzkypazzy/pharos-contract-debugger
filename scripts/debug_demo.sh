#!/bin/bash

# Pharos Contract Debugger - Rich Output Demo
# Same diagnostics as debug.sh, but uses `cast` + `jq` for cleaner parsing.
# Needs: cast (Foundry) and jq. Falls back to debug.sh if either is missing.

set -euo pipefail

# -------- arg parsing --------
TX_HASH="${1:-}"
NETWORK_OVERRIDE=""
shift || true
while [ $# -gt 0 ]; do
  case "$1" in
    --network) NETWORK_OVERRIDE="$2"; shift 2 ;;
    --network=*) NETWORK_OVERRIDE="${1#*=}"; shift ;;
    -h|--help)
      echo "Usage: bash scripts/debug_demo.sh [TX_HASH] [--network mainnet|testnet]"
      exit 0
      ;;
    *) echo "Unknown arg: $1"; exit 1 ;;
  esac
done

# -------- soft dep check --------
if ! command -v cast >/dev/null 2>&1; then
  echo "⚠️  'cast' (Foundry) not found. Falling back to debug.sh (curl-only)."
  exec bash "$(dirname "${BASH_SOURCE[0]}")/debug.sh" "$TX_HASH" ${NETWORK_OVERRIDE:+--network $NETWORK_OVERRIDE}
fi
if ! command -v jq >/dev/null 2>&1; then
  echo "⚠️  'jq' not found. Falling back to debug.sh (curl-only)."
  exec bash "$(dirname "${BASH_SOURCE[0]}")/debug.sh" "$TX_HASH" ${NETWORK_OVERRIDE:+--network $NETWORK_OVERRIDE}
fi

# -------- load network config --------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NET_JSON="$SCRIPT_DIR/../references/networks.json"

NET="${NETWORK_OVERRIDE:-testnet}"
case "$NET" in
  testnet|atlantic|atlantic-testnet) NET_KEY="atlantic-testnet" ;;
  mainnet|pacific|pacific-mainnet)   NET_KEY="mainnet" ;;
  *) echo "Unknown network: $NET"; exit 1 ;;
esac

RPC_URL=$(jq -r ".networks[] | select(.name==\"$NET_KEY\") | .rpcUrl" "$NET_JSON")
EXPLORER_URL=$(jq -r ".networks[] | select(.name==\"$NET_KEY\") | .explorerUrl" "$NET_JSON")
CHAIN_ID=$(jq -r ".networks[] | select(.name==\"$NET_KEY\") | .chainId" "$NET_JSON")
NATIVE=$(jq -r ".networks[] | select(.name==\"$NET_KEY\") | .nativeToken" "$NET_JSON")
DISPLAY_NAME=$(jq -r ".networks[] | select(.name==\"$NET_KEY\") | .displayName" "$NET_JSON")

# -------- tx hash (fall back to a real mainnet tx if none given) --------
if [ -z "$TX_HASH" ]; then
  echo ""
  echo "ℹ️  No tx hash provided — using a real public mainnet tx as a sample."
  echo "   Pass any Pharos tx hash as the first arg to debug your own."
  echo "   For a *failed* tx demo, paste any reverted hash from your wallet or"
  echo "   pull one from https://www.pharosscan.xyz (filter status=Failed)."
  echo ""
  # A confirmed-success mainnet tx so the demo at least shows the success path
  TX_HASH="0x9606bcfd027b28e6783ca8b5fef1c3311476a1c30e5bf4464d0340a0d24ba7f7"
fi

echo ""
echo "======================================"
echo "  PHAROS CONTRACT DEBUGGER (rich)"
echo "======================================"
echo " Network:  $DISPLAY_NAME (chain $CHAIN_ID)"
echo " Currency: $NATIVE"
echo " RPC:      $RPC_URL"
echo " TX:       $TX_HASH"
echo ""

# -------- fetch --------
RECEIPT_JSON=$(cast receipt "$TX_HASH" --rpc-url "$RPC_URL" --json 2>/dev/null)
TX_JSON=$(cast tx "$TX_HASH" --rpc-url "$RPC_URL" --json 2>/dev/null)

if [ -z "$RECEIPT_JSON" ] || [ "$RECEIPT_JSON" = "null" ]; then
  echo "❌ Transaction not found on $DISPLAY_NAME."
  OTHER=$([ "$NET_KEY" = "mainnet" ] && echo testnet || echo mainnet)
  echo "   Try: bash scripts/debug_demo.sh $TX_HASH --network $OTHER"
  exit 1
fi

STATUS=$(echo "$RECEIPT_JSON" | jq -r '.status')
GAS_USED_HEX=$(echo "$RECEIPT_JSON" | jq -r '.gasUsed')
GAS_USED=$(( GAS_USED_HEX ))   # bash auto-handles 0x prefix in $(( )) on bash 4+
GAS_USED=$(( GAS_USED ))       # belt-and-suspenders
FROM=$(echo "$RECEIPT_JSON"     | jq -r '.from')
TO=$(echo "$RECEIPT_JSON"       | jq -r '.to')
BLOCK_HEX=$(echo "$RECEIPT_JSON" | jq -r '.blockNumber')
BLOCK=$(( BLOCK_HEX ))

GAS_LIMIT_HEX=$(echo "$TX_JSON" | jq -r '.gas')
GAS_LIMIT=$(( GAS_LIMIT_HEX ))
EFFGP_HEX=$(echo "$RECEIPT_JSON" | jq -r '.effectiveGasPrice // "0x0"')
EFFGP=$(( EFFGP_HEX ))

echo "--------------------------------------"
echo " Sender:   $FROM"
echo " To:       $TO"
echo " Block:    $BLOCK"
echo " Gas:      $GAS_USED / $GAS_LIMIT  (effective: $EFFGP wei)"
echo "--------------------------------------"
echo ""

# -------- diagnose --------
if [ "$STATUS" = "0x1" ]; then
  echo "RESULT: ✅ TRANSACTION SUCCESSFUL"
  PCT=$(( GAS_USED * 100 / (GAS_LIMIT == 0 ? 1 : GAS_LIMIT) ))
  echo " Gas utilization: ${PCT}%"
elif [ "$STATUS" = "0x0" ]; then
  echo "RESULT: ❌ TRANSACTION FAILED"
  echo ""
  echo "STEP 2: Identifying the cause..."

  # 1. Out of gas?
  if [ "$GAS_USED" -ge "$GAS_LIMIT" ] && [ "$GAS_LIMIT" -gt 0 ]; then
    echo ""
    echo "--------------------------------------"
    echo " Cause:   OUT OF GAS"
    echo " Detail:  used=$GAS_USED limit=$GAS_LIMIT"
    echo " Fix:     Re-send with gas_limit ≈ gasUsed × 1.3"
    echo "           cast estimate $TO \"<SIG>\" <ARGS...> \\"
    echo "             --rpc-url $RPC_URL --from $FROM"
    echo "--------------------------------------"
    exit 0
  fi

  # 2. Try to pull a 4-byte selector from the call's returndata
  #    `cast receipt --json` doesn't always expose revertReason across all RPCs.
  #    Fall back to: run a `cast call ... | cast 4byte-decode` if the call data is available.
  SELECTOR=""
  if command -v python3 >/dev/null 2>&1; then
    # Look for a 4-byte hex string in the raw receipt that looks like a selector
    SELECTOR=$(echo "$RECEIPT_JSON" \
      | python3 -c "import json,sys,re; r=json.load(sys.stdin); blob=json.dumps(r); m=re.search(r'0x[a-fA-F0-9]{8}', blob); print(m.group(0) if m else '')")
  fi

  # 3. Pull calldata from the original tx and try to extract the function selector
  #    (first 4 bytes of tx input) — that tells us *what* the user called.
  INPUT=$(echo "$TX_JSON" | jq -r '.input // "0x"')
  FN_SELECTOR="${INPUT:0:10}"

  echo ""
  if [ -n "$SELECTOR" ]; then
    LABEL=$(cast 4byte-decode "$SELECTOR" 2>/dev/null || echo "(unknown)")
    echo "--------------------------------------"
    echo " Revert selector: $SELECTOR"
    echo " Decoded name:    $LABEL"
    if [ -n "$FN_SELECTOR" ] && [ "$FN_SELECTOR" != "0x" ]; then
      FN_NAME=$(cast 4byte-decode "$FN_SELECTOR" 2>/dev/null || echo "(unknown)")
      echo " Called:          $FN_SELECTOR  $FN_NAME"
    fi
    echo "--------------------------------------"
    echo ""
    echo "STEP 3: Likely cause & fix"
    case "$SELECTOR" in
      0x13be252b)
        echo " → ERC20: insufficient allowance."
        echo "   Call approve(spender, amount) first."
        ;;
      0xf4d758bb)
        echo " → ERC20: insufficient balance."
        echo "   Top up the sender's balance for the token you tried to transfer."
        ;;
      0x118cdaa7)
        echo " → Ownable: caller is not the owner."
        echo "   Re-send from the contract owner address."
        ;;
      0x4e487b71)
        echo " → Panic(uint256). Replay with --debug for the panic code."
        echo "   cast run $TX_HASH --rpc-url $RPC_URL --debug"
        ;;
      0x08c379a0)
        echo " → Error(string). Run with --debug to see the message."
        echo "   cast run $TX_HASH --rpc-url $RPC_URL --debug"
        ;;
      *)
        echo " → See references/error-patterns.md for the full selector table."
        echo "   cast 4byte-decode $SELECTOR"
        ;;
    esac
  else
    echo "--------------------------------------"
    echo " Cause:   TRANSACTION REVERTED (no revert data)"
    if [ -n "$FN_SELECTOR" ] && [ "$FN_SELECTOR" != "0x" ]; then
      FN_NAME=$(cast 4byte-decode "$FN_SELECTOR" 2>/dev/null || echo "(unknown)")
      echo " Called:  $FN_SELECTOR  $FN_NAME"
    fi
    echo ""
    echo " Common causes on Pharos:"
    echo "   • Insufficient token balance or allowance"
    echo "   • Access control / missing role"
    echo "   • Slippage exceeded on DEX swap"
    echo "   • Contract paused or not initialized"
    echo "   • Wrong function arguments"
    echo ""
    echo " To get the full trace:"
    echo "   cast run $TX_HASH --rpc-url $RPC_URL --debug"
    echo "--------------------------------------"
  fi
else
  echo "RESULT: ⚠️ UNKNOWN STATUS ($STATUS)"
fi

echo ""
echo " Explorer: ${EXPLORER_URL}tx/$TX_HASH"
echo " Network:  $DISPLAY_NAME (chain $CHAIN_ID)"
echo "======================================"
