#!/bin/bash

# pharos-contract-debugger — Foundry-port debug script.
# All RPC reads go through `cast` (no curl, no jq, no Python).
# Network config is loaded from assets/networks.json.
#
# Usage: bash scripts/debug.sh <TX_HASH> [--network mainnet|testnet]

# Foundry is mandatory for this script.
if ! command -v cast >/dev/null 2>&1; then
  echo "Error: 'cast' not found. Install Foundry:"
  echo "  curl -L https://foundry.paradigm.xyz | bash && foundryup"
  exit 1
fi

# -------- arg parsing --------
TX_HASH=""
NETWORK_OVERRIDE=""
PRINT_HELP=0
PREV=""
for arg in "$@"; do
  case "$PREV" in
    --network) NETWORK_OVERRIDE="$arg"; PREV=""; continue ;;
  esac
  case "$arg" in
    -h|--help)  PRINT_HELP=1 ;;
    --network)   PREV="--network" ;;
    --network=*) NETWORK_OVERRIDE="${arg#*=}" ;;
    -*)          echo "Unknown flag: $arg"; exit 1 ;;
    *)           [ -z "$TX_HASH" ] && TX_HASH="$arg" ;;
  esac
done
[ "$PREV" = "--network" ] && { echo "Error: --network requires a value"; exit 1; }

if [ "$PRINT_HELP" = "1" ]; then
  cat <<'USAGE'
Usage: bash scripts/debug.sh <TX_HASH> [--network mainnet|testnet]

Examples:
  bash scripts/debug.sh 0xabc... --network mainnet
  bash scripts/debug.sh 0xabc... --network testnet

Networks: mainnet (Pacific Ocean, chain 1672) and testnet (Atlantic, chain 688689).

Prerequisites:
  - Foundry installed (cast/forge): curl -L https://foundry.paradigm.xyz | bash
USAGE
  exit 0
fi

if [ -z "$TX_HASH" ]; then
  echo "Usage: bash scripts/debug.sh <TX_HASH> [--network mainnet|testnet]"
  exit 1
fi

# -------- load network config from assets/networks.json --------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NET_JSON="$SCRIPT_DIR/../assets/networks.json"
[ ! -f "$NET_JSON" ] && { echo "Error: $NET_JSON not found"; exit 1; }

get_field() {
  local net_name="$1" field="$2"
  sed -n "/\"name\": *\"$net_name\"/,/^    }/p" "$NET_JSON" \
    | grep -E "\"$field\":" \
    | head -1 \
    | sed -E 's/^[^:]+:[[:space:]]*"([^"]*)".*/\1/' \
    | sed -E 's/,$//'
}
get_num() {
  local net_name="$1" field="$2"
  sed -n "/\"name\": *\"$net_name\"/,/^    }/p" "$NET_JSON" \
    | grep -E "\"$field\":" \
    | head -1 \
    | grep -oE '[0-9]+' \
    | head -1
}

NET="${NETWORK_OVERRIDE:-testnet}"
case "$NET" in
  testnet|atlantic|atlantic-testnet) NET_KEY="atlantic-testnet" ;;
  mainnet|pacific|pacific-mainnet)   NET_KEY="mainnet" ;;
  *) echo "Unknown network: $NET"; exit 1 ;;
esac

RPC_URL=$(get_field     "$NET_KEY" "rpcUrl")
EXPLORER_URL=$(get_field "$NET_KEY" "explorerUrl")
CHAIN_ID=$(get_num      "$NET_KEY" "chainId")
NATIVE=$(get_field      "$NET_KEY" "nativeToken")

# -------- render header --------
echo ""
echo "🔍 Pharos Contract Debugger (Foundry)"
echo "========================================"
echo "Network: $NET_KEY"
echo "Chain:   $CHAIN_ID ($NATIVE)"
echo "RPC:     $RPC_URL"
echo "TX:      $TX_HASH"
echo ""

# -------- fetch receipt via cast --------
echo "📡 Fetching transaction receipt via cast..."
RECEIPT_JSON=$(cast receipt --rpc-url "$RPC_URL" "$TX_HASH" --json 2>/dev/null || echo "")

if [ -z "$RECEIPT_JSON" ] || [ "$RECEIPT_JSON" = "null" ] || ! echo "$RECEIPT_JSON" | grep -q '"status"'; then
  echo "❌ Transaction not found on $NET_KEY."
  OTHER=$([ "$NET_KEY" = "mainnet" ] && echo testnet || echo mainnet)
  echo "   Try: bash scripts/debug.sh $TX_HASH --network $OTHER"
  exit 1
fi

# -------- extract via cast (no manual JSON parsing) --------
STATUS=$(cast receipt --rpc-url "$RPC_URL" "$TX_HASH" status 2>/dev/null | tr -d '\n')
GAS_USED_HEX=$(cast receipt --rpc-url "$RPC_URL" "$TX_HASH" gasUsed 2>/dev/null | tr -d '\n')
BLOCK_HEX=$(cast receipt --rpc-url "$RPC_URL" "$TX_HASH" blockNumber 2>/dev/null | tr -d '\n')
TO=$(cast receipt --rpc-url "$RPC_URL" "$TX_HASH" to 2>/dev/null | tr -d '\n')
FROM=$(cast receipt --rpc-url "$RPC_URL" "$TX_HASH" from 2>/dev/null | tr -d '\n')

# Compare gas limit vs gas used
GAS_LIMIT_HEX=$(cast tx --rpc-url "$RPC_URL" "$TX_HASH" gasLimit 2>/dev/null | tr -d '\n')
GAS_USED=$(cast --to-dec "$GAS_USED_HEX" 2>/dev/null | tr -d '\n')
GAS_LIMIT=$(cast --to-dec "$GAS_LIMIT_HEX" 2>/dev/null | tr -d '\n')
BLOCK=$(cast --to-dec "$BLOCK_HEX" 2>/dev/null | tr -d '\n')

# -------- common known-error labels (no external dep) --------
label_for_selector() {
  case "$1" in
    0x08c379a0) echo "Error(string) — custom string revert" ;;
    0x4e487b71) echo "Panic(uint256) — runtime panic (overflow / OOB / div-by-0)" ;;
    0x13be252b) echo "ERC20: insufficient allowance" ;;
    0xf4d758bb) echo "ERC20: insufficient balance" ;;
    0x118cdaa7) echo "Ownable: caller is not the owner" ;;
    0xe6c4247b) echo "ECDSA: invalid signature" ;;
    0xfb8f41b2) echo "ECDSA: invalid signature length" ;;
    0x2cf07b6c) echo "AccessControl: account is missing role" ;;
    *)          echo "Unknown custom error" ;;
  esac
}

# -------- render body --------
echo "📊 TRANSACTION DETAILS"
echo "----------------------"
echo "Block:    $BLOCK"
echo "From:     $FROM"
echo "To:       $TO"
echo "Gas:      $GAS_USED used / $GAS_LIMIT limit"
echo ""

if [ "$STATUS" = "0x1" ]; then
  echo "✅ STATUS: SUCCESS"
  echo "   Transaction executed successfully."
  [ "$GAS_LIMIT" -gt 0 ] 2>/dev/null && {
    PCT=$(( GAS_USED * 100 / GAS_LIMIT ))
    echo "   Gas utilization: ${PCT}%"
  }
else
  echo "❌ STATUS: FAILED"
  echo ""
  echo "🔎 DIAGNOSIS"
  echo "------------"

  if [ "$GAS_LIMIT" -gt 0 ] 2>/dev/null && [ "$GAS_USED" -ge "$GAS_LIMIT" ]; then
    echo "🚨 CAUSE: OUT OF GAS"
    echo "   Gas used ($GAS_USED) reached the gas limit ($GAS_LIMIT)."
    echo ""
    echo "   FIX:"
    echo "     cast estimate $TO \"<SIG>\" <ARGS...> --rpc-url $RPC_URL --from $FROM"
    echo "     # then re-send with gas_limit = estimate × 1.3"
  else
    # Try to decode the revert reason via cast
    REVERT_BLOB=$(cast run --rpc-url "$RPC_URL" "$TX_HASH" 2>&1 | grep -E "│ revert" | head -1 | awk '{print $NF}' | tr -d '│' || echo "")
    if [ -n "$REVERT_BLOB" ] && [[ "$REVERT_BLOB" == 0x* ]] && [ "${#REVERT_BLOB}" -ge 10 ]; then
      SELECTOR="${REVERT_BLOB:0:10}"
      LABEL=$(label_for_selector "$SELECTOR")
      echo "⚠️  CAUSE: REVERTED WITH CUSTOM ERROR"
      echo "   Selector: $SELECTOR"
      echo "   Decoded:  $LABEL"
      echo ""
      echo "   To see the full error string:"
      echo "     cast 4byte-decode $SELECTOR"
    else
      echo "⚠️  CAUSE: TRANSACTION REVERTED (no error data)"
      echo "   Common causes on Pharos:"
      echo "   • Insufficient token balance or allowance"
      echo "   • Access control / missing role"
      echo "   • Slippage exceeded on DEX swap"
      echo "   • Contract paused or not initialized"
      echo "   • Wrong function arguments"
      echo ""
      echo "   To diagnose further:"
      echo "     cast run $TX_HASH --rpc-url $RPC_URL"
    fi
  fi
fi

echo ""
echo "🔗 View on Explorer: ${EXPLORER_URL}tx/$TX_HASH"
echo "📡 Network: $NET_KEY (chain $CHAIN_ID)"
