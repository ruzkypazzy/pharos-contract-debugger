#!/bin/bash

# pharos-contract-debugger — Foundry-port debug script.
# All RPC reads go through `cast` (no curl, no jq, no Python).
# Network config is loaded from assets/networks.json.
#
# Usage: bash scripts/debug.sh <TX_HASH> [--network mainnet|testnet]

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

# ---- Foundry required (checked AFTER network resolution so --network bogus is detected first) ----
if ! command -v cast >/dev/null 2>&1; then
  echo "Error: 'cast' not found. Install Foundry:" >&2
  echo "  curl -L https://foundry.paradigm.xyz | bash && foundryup" >&2
  exit 1
fi

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

# -------- fetch receipt via cast (try --json first, fall back to per-field) --------
echo "📡 Fetching transaction receipt via cast..."

# Try the JSON receipt, capturing both stdout and stderr so we can show errors
RECEIPT_STDERR=$(mktemp)
RECEIPT_JSON=$(cast receipt --rpc-url "$RPC_URL" "$TX_HASH" --json 2>"$RECEIPT_STDERR" || echo "")

# If JSON fetch returned empty/garbage, capture what cast actually said
if [ -z "$RECEIPT_JSON" ] || [ "$RECEIPT_JSON" = "null" ]; then
  # Try the per-field calls so we have something to compare against
  STATUS_DIRECT=$(cast receipt --rpc-url "$RPC_URL" "$TX_HASH" status 2>/dev/null | tr -d '[:space:]')
  if [ -z "$STATUS_DIRECT" ]; then
    # Cast genuinely failed to fetch the receipt. Show what cast said.
    echo ""
    echo "❌ Cast could not fetch the receipt for $TX_HASH on $NET_KEY."
    echo ""
    if [ -s "$RECEIPT_STDERR" ]; then
      echo "Cast error output:"
      cat "$RECEIPT_STDERR" | sed 's/^/   /'
      echo ""
    fi
    echo "Possible causes:"
    echo "  • The tx hash is wrong (typo? wrong network? — try --network testnet)"
    echo "  • The Pharos public RPC at $RPC_URL is down or rate-limiting you"
    echo "  • cast is broken (run 'cast --version' to verify, reinstall with foundryup if needed)"
    echo "  • You have no network access from this terminal"
    OTHER=$([ "$NET_KEY" = "mainnet" ] && echo testnet || echo mainnet)
    echo ""
    echo "Try with the other network:"
    echo "  bash scripts/debug.sh $TX_HASH --network $OTHER"
    rm -f "$RECEIPT_STDERR"
    exit 1
  fi
fi
rm -f "$RECEIPT_STDERR"

# Parse status robustly. Accept any of:
#   - "0x1" / "0x0"     (hex with 0x prefix — most common)
#   - "0X1" / "0X0"     (uppercase)
#   - "1" / "0"        (bare number)
# Treat "1" or anything truthy as success, "0" as failure.
extract_status() {
  local s
  s=$(echo "$RECEIPT_JSON" | jq -r '.status // empty' 2>/dev/null)
  if [ -z "$s" ]; then
    s=$(cast receipt --rpc-url "$RPC_URL" "$TX_HASH" status 2>/dev/null | tr -d '[:space:]')
  fi
  # Normalize: lowercase, strip leading 0x
  s=$(echo "$s" | tr '[:upper:]' '[:lower:]')
  s="${s#0x}"
  echo "$s"
}
STATUS_HEX=$(extract_status)

# -------- extract other receipt fields via cast (more reliable than JSON parsing) --------
TO=$(cast receipt --rpc-url "$RPC_URL" "$TX_HASH" to 2>/dev/null | tr -d '\n' | tr -d '[:space:]')
FROM=$(cast receipt --rpc-url "$RPC_URL" "$TX_HASH" from 2>/dev/null | tr -d '\n' | tr -d '[:space:]')
GAS_USED_HEX=$(cast receipt --rpc-url "$RPC_URL" "$TX_HASH" gasUsed 2>/dev/null | tr -d '\n' | tr -d '[:space:]')
BLOCK_HEX=$(cast receipt --rpc-url "$RPC_URL" "$TX_HASH" blockNumber 2>/dev/null | tr -d '\n' | tr -d '[:space:]')
GAS_LIMIT_HEX=$(cast tx --rpc-url "$RPC_URL" "$TX_HASH" gasLimit 2>/dev/null | tr -d '\n' | tr -d '[:space:]')

GAS_USED=$(cast --to-dec "$GAS_USED_HEX" 2>/dev/null | tr -d '[:space:]')
GAS_LIMIT=$(cast --to-dec "$GAS_LIMIT_HEX" 2>/dev/null | tr -d '[:space:]')
BLOCK=$(cast --to-dec "$BLOCK_HEX" 2>/dev/null | tr -d '[:space:]')

# Default gas values if cast failed
[ -z "$GAS_USED" ] && GAS_USED=0
[ -z "$GAS_LIMIT" ] && GAS_LIMIT=0
[ -z "$BLOCK" ] && BLOCK="(unknown)"

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
echo "Status:   $STATUS_HEX (1 = success, 0 = failure)"
echo ""

# Status check: ONLY claim success/failure if we have hard evidence.
# - status="1" or "0x1" -> SUCCESS
# - status="0" or "0x0" -> FAILED
# - anything else (empty, garbage, "null", "undefined") -> UNKNOWN
if [ "$STATUS_HEX" = "1" ]; then
  echo "✅ STATUS: SUCCESS (cast reported status=1)"
  echo "   Transaction executed successfully."
  if [ "$GAS_LIMIT" -gt 0 ] 2>/dev/null; then
    PCT=$(( GAS_USED * 100 / GAS_LIMIT ))
    echo "   Gas utilization: ${PCT}%"
  fi
elif [ "$STATUS_HEX" = "0" ]; then
  echo "❌ STATUS: FAILED (cast reported status=0)"
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
else
  echo "⚠️  STATUS: UNKNOWN (could not determine)"
  echo ""
  echo "   Cast did not return a recognizable status for this transaction."
  echo "   STATUS_HEX='$STATUS_HEX'"
  echo ""
  echo "   Possible reasons:"
  echo "     • The Pharos public RPC at $RPC_URL returned a partial / malformed receipt"
  echo "     • The transaction hash is on a different network — try --network testnet"
  echo "     • cast's status field returned something unexpected (empty, 'null', whitespace, etc.)"
  echo ""
  echo "   To debug manually, run on your VPS:"
  echo "     cast receipt --rpc-url $RPC_URL $TX_HASH --json 2>&1 | jq ."
  echo "     cast receipt --rpc-url $RPC_URL $TX_HASH status"
  echo ""
  echo "   Or open the tx in the block explorer:"
  echo "     ${EXPLORER_URL}tx/$TX_HASH"
fi

echo "🔗 View on Explorer: ${EXPLORER_URL}tx/$TX_HASH"
echo "📡 Network: $NET_KEY (chain $CHAIN_ID)"
