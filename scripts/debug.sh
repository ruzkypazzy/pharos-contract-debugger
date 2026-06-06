#!/bin/bash

# Pharos Contract Debugger - Live Transaction Analyzer
# Networks: Pharos Atlantic Testnet (688689), Pharos Pacific Mainnet (1672)
# Reads network config from references/networks.json so URLs/IDs never go stale.
#
# Usage: bash scripts/debug.sh <TX_HASH> [--network mainnet|testnet]
# Zero-deps: bash, curl. No cast / jq required.

# NOTE: deliberately NOT using `set -e` here. The script does a lot of optional
# curl/grep work; we want to keep going when an optional field is empty rather
# than abort on the first miss. We do `|| true` on every optional extraction.

# -------- arg parsing --------
# Walk the args: the first non-flag arg is the tx hash. Any --flag form that
# takes a value (like --network FOO) consumes the next arg.
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
# Leftover --network with no value: error
if [ "$PREV" = "--network" ]; then
  echo "Error: --network requires a value (mainnet or testnet)"
  exit 1
fi

if [ "$PRINT_HELP" = "1" ]; then
  cat <<'USAGE'
Usage: bash scripts/debug.sh <TX_HASH> [--network mainnet|testnet]

Examples:
  bash scripts/debug.sh 0xabc... --network mainnet
  bash scripts/debug.sh 0xabc... --network testnet

Networks: mainnet (Pacific Ocean, chain 1672) and testnet (Atlantic, chain 688689).
USAGE
  exit 0
fi

if [ -z "$TX_HASH" ]; then
  echo "Usage: bash scripts/debug.sh <TX_HASH> [--network mainnet|testnet]"
  echo "Example: bash scripts/debug.sh 0xabc... --network mainnet"
  exit 1
fi

# -------- load network config from references/networks.json (no jq dep) --------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NET_JSON="$SCRIPT_DIR/../references/networks.json"
if [ ! -f "$NET_JSON" ]; then
  echo "❌ references/networks.json not found at $NET_JSON"
  exit 1
fi

# Tiny sed-based JSON parser: pull the block from "name": "<key>" to next
# closing-brace line, then extract a field by name.
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
  *) echo "Unknown network: $NET (use 'testnet' or 'mainnet')"; exit 1 ;;
esac

RPC_URL=$(get_field     "$NET_KEY" "rpcUrl")
EXPLORER_URL=$(get_field "$NET_KEY" "explorerUrl")
CHAIN_ID=$(get_num      "$NET_KEY" "chainId")
NATIVE=$(get_field      "$NET_KEY" "nativeToken")
DISPLAY_NAME=$(get_field "$NET_KEY" "displayName")

# -------- render header --------
echo ""
echo "🔍 Pharos Contract Debugger"
echo "================================"
echo "Network: $DISPLAY_NAME"
echo "Chain:   $CHAIN_ID ($NATIVE)"
echo "RPC:     $RPC_URL"
echo "TX:      $TX_HASH"
echo ""

# -------- fetch receipt --------
echo "📡 Fetching transaction receipt..."
RECEIPT=$(curl -s -X POST "$RPC_URL" \
  -H "Content-Type: application/json" \
  -d "{\"jsonrpc\":\"2.0\",\"method\":\"eth_getTransactionReceipt\",\"params\":[\"$TX_HASH\"],\"id\":1}" \
  || echo "")

if [ -z "$RECEIPT" ] || echo "$RECEIPT" | grep -q '"result":null'; then
  echo "❌ Transaction not found on $DISPLAY_NAME."
  echo "   • Check the hash"
  echo "   • Make sure it was sent to chain $CHAIN_ID"
  OTHER=$([ "$NET_KEY" = "mainnet" ] && echo testnet || echo mainnet)
  echo "   • Try: bash scripts/debug.sh $TX_HASH --network $OTHER"
  exit 1
fi

# -------- extract fields (each is best-effort, never fatal) --------
extract_hex() {
  echo "$RECEIPT" \
    | grep -o "\"$1\":\"0x[^\"]*\"" \
    | head -1 \
    | grep -o '0x[^"]*' \
    | head -1
}
extract_hex_tx() {
  echo "$2" \
    | grep -o "\"$1\":\"0x[^\"]*\"" \
    | head -1 \
    | grep -o '0x[^"]*' \
    | head -1
}
hex_to_dec() {
  local v="$1"
  if [ -z "$v" ] || [ "$v" = "0x" ]; then echo "0"; return; fi
  printf "%d" "$v" 2>/dev/null || echo "0"
}

STATUS=$(extract_hex  status   | tr -d '\n')
GAS_USED_HEX=$(extract_hex gasUsed)
BLOCK_HEX=$(extract_hex   blockNumber)
TO=$(extract_hex          to)
FROM=$(extract_hex        from)

GAS_USED=$(hex_to_dec "$GAS_USED_HEX")
BLOCK=$(hex_to_dec     "$BLOCK_HEX")

# Fetch the original tx to compare gasLimit vs gasUsed (best-effort)
TX=$(curl -s -X POST "$RPC_URL" \
  -H "Content-Type: application/json" \
  -d "{\"jsonrpc\":\"2.0\",\"method\":\"eth_getTransactionByHash\",\"params\":[\"$TX_HASH\"],\"id\":1}" \
  || echo "")
GAS_LIMIT_HEX=$(extract_hex_tx gas "$TX")
GAS_LIMIT=$(hex_to_dec "$GAS_LIMIT_HEX")

# Try to extract a 4-byte revert selector from the receipt's revertReason field
# (some RPC nodes expose it; this is a best-effort lookup, not a guarantee)
REVERT_SELECTOR=""
if echo "$RECEIPT" | grep -q '"revertReason":"0x'; then
  REVERT_SELECTOR=$(echo "$RECEIPT" \
    | grep -o '"revertReason":"0x[a-fA-F0-9]\{8\}"' \
    | head -1 \
    | grep -oE '0x[a-fA-F0-9]{8}')
fi

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
  if [ "$GAS_LIMIT" -gt 0 ] 2>/dev/null; then
    PCT=$(( GAS_USED * 100 / GAS_LIMIT ))
    echo "   Gas utilization: ${PCT}%"
  fi
else
  echo "❌ STATUS: FAILED"
  echo ""
  echo "🔎 DIAGNOSIS"
  echo "------------"

  # Out of gas check
  if [ "$GAS_LIMIT" -gt 0 ] 2>/dev/null && [ "$GAS_USED" -ge "$GAS_LIMIT" ]; then
    echo "🚨 CAUSE: OUT OF GAS"
    echo "   Gas used ($GAS_USED) reached the gas limit ($GAS_LIMIT)."
    echo ""
    echo "   FIX:"
    echo "     cast estimate $TO \"<SIG>\" <ARGS...> --rpc-url $RPC_URL --from $FROM"
    echo "     # then re-send with gas_limit = estimate × 1.3"
  elif [ -n "$REVERT_SELECTOR" ]; then
    LABEL=$(label_for_selector "$REVERT_SELECTOR")
    echo "⚠️  CAUSE: REVERTED WITH CUSTOM ERROR"
    echo "   Selector: $REVERT_SELECTOR"
    echo "   Decoded:  $LABEL"
    echo ""
    echo "   To see the full error string (if it's Error(string)):"
    echo "     cast 4byte-decode $REVERT_SELECTOR"
    echo "     # or replay with trace:"
    echo "     cast run $TX_HASH --rpc-url $RPC_URL --debug"
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
    echo "     cast run $TX_HASH --rpc-url $RPC_URL --debug"
  fi
fi

echo ""
echo "🔗 View on Explorer: ${EXPLORER_URL}tx/$TX_HASH"
echo "📡 Network: $DISPLAY_NAME (chain $CHAIN_ID)"
