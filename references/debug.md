# Transaction Debugging Reference

Complete guide for debugging failed transactions on Pharos using Foundry's `cast` and raw `curl`. Both `atlantic-testnet` (chain 688689) and `mainnet` (chain 1672) are supported.

## Network configuration

Read from `references/networks.json` so URLs and chain IDs never go stale. To use in a shell session:

```bash
# Pick a network and export
NET_JSON="$(dirname "$0")/../references/networks.json"

# Atlantic Testnet (default — matches the official pharos-skill-engine)
export RPC_URL=$(jq -r '.networks[] | select(.name=="atlantic-testnet") | .rpcUrl' "$NET_JSON")
export CHAIN_ID=$(jq -r '.networks[] | select(.name=="atlantic-testnet") | .chainId' "$NET_JSON")

# Mainnet
export RPC_URL=$(jq -r '.networks[] | select(.name=="mainnet") | .rpcUrl' "$NET_JSON")
export CHAIN_ID=$(jq -r '.networks[] | select(.name=="mainnet") | .chainId' "$NET_JSON")
```

Canonical values:

| Network | Chain ID | RPC | Explorer |
|---|---:|---|---|
| Atlantic Testnet | 688689 | `https://atlantic.dplabs-internal.com` | https://atlantic.pharosscan.xyz |
| Mainnet | 1672 | `https://rpc.pharos.xyz` | https://www.pharosscan.xyz |

## Transaction inspection

### Basic transaction query

```bash
cast tx <TX_HASH> --rpc-url $RPC_URL
```

### Receipt (status, gas, logs)

```bash
cast receipt <TX_HASH> --rpc-url $RPC_URL
cast receipt <TX_HASH> --rpc-url $RPC_URL --json | jq .
```

**Key fields in the receipt:**

| Field | Description |
|---|---|
| `status` | `0x1` = success, `0x0` = failed |
| `gasUsed` | Gas actually consumed |
| `effectiveGasPrice` | Wei per gas at execution |
| `from` / `to` | Sender and callee (or `null` for contract creation) |
| `logs` | Event log array — may carry error data on the last entry |
| `contractAddress` | Non-null only for contract-creation txs |

### Replay with full trace (the power move)

`cast run` re-executes the tx against current state and gives you a per-opcode trace. Use this when the receipt alone doesn't tell you *which* internal call reverted:

```bash
cast run <TX_HASH> --rpc-url $RPC_URL --debug
```

This is how you read a `Panic(uint256)` code or a nested `Error(string)` revert.

## Revert reason decoding

### By selector (4-byte hash)

```bash
cast 4byte-decode 0x08c379a0   # Error(string)
cast 4byte-decode 0x4e487b71   # Panic(uint256)
cast 4byte-decode 0x13be252b   # ERC20: insufficient allowance
cast 4byte-decode 0xf4d758bb   # ERC20: insufficient balance
cast 4byte-decode 0x118cdaa7   # Ownable: caller is not the owner
```

For unknown selectors, `cast 4byte` will look them up against the public 4byte.directory.

### Reading `Error(string)` returns

The first 4 bytes are the selector; the next 32 bytes are the offset to the string data; then a length-prefixed UTF-8 string. To decode it:

```bash
# Pull the raw returndata
RAW=$(cast run <TX_HASH> --rpc-url $RPC_URL --debug 2>&1 | grep -A 1 "REVERT" | tail -1)
# Then ABI-decode the (string) tuple
cast --abi-decode "decodeError(string)" "$RAW"
```

For one-shot decoding, `cast 4byte-decode` plus a short Python helper works:

```python
def decode_string_returndata(data: str) -> str:
    assert data.startswith("0x08c379a0"), "not an Error(string) revert"
    payload = bytes.fromhex(data[10:])
    # offset = first 32 bytes (skip; assume 0x20)
    length = int.from_bytes(payload[32:64], "big")
    msg = payload[64:64+length]
    return msg.decode("utf-8", errors="replace")
```

### Panic codes

`Panic(uint256)` is selector `0x4e487b71` with a single uint256 code:

| Code | Meaning |
|---|---|
| `0x01` | Assert failed |
| `0x11` | Arithmetic overflow / underflow |
| `0x12` | Division or modulo by zero |
| `0x21` | Conversion to enum out of bounds |
| `0x22` | Storage array access out of bounds |
| `0x31` | Empty array `.pop()` |
| `0x32` | Array index out of bounds |
| `0x41` | Memory allocation too large |
| `0x51` | Called an uninitialized internal function |

## Gas analysis

```bash
# Compare gas used vs gas limit
cast receipt <TX_HASH> --rpc-url $RPC_URL --json | jq '{gasUsed, gas: .gas}'

# Estimate for a similar call (replaces the failed one)
cast estimate <TO> "<SIG>" <ARGS...> --rpc-url $RPC_URL --from <FROM>

# Current network gas price
cast gas-price --rpc-url $RPC_URL
```

**Diagnosis table:**

| gasUsed | gas (limit) | Likely cause |
|---|---|---|
| == limit | high | Out of gas — re-send with 1.3× the limit |
| low | normal | Underpriced gas-price *or* revert early in execution |
| mid | normal | Internal revert with normal gas consumption — re-run with --debug |

## Common debugging workflows

### Workflow 1: triage a single hash

```bash
TX="0x..."
RPC="https://rpc.pharos.xyz"

# 1. Status
cast receipt "$TX" --rpc-url "$RPC" --json | jq '{status, gasUsed, from, to}'

# 2. If failed, get the full trace
cast run "$TX" --rpc-url "$RPC" --debug

# 3. Decode any 4-byte selector you find
cast 4byte-decode 0xSEL...
```

### Workflow 2: triage a *contract* (a contract whose txs keep failing)

```bash
CONTRACT="0x..."
RPC="https://rpc.pharos.xyz"

# Last 100 txs to that contract
cast block 0 --rpc-url "$RPC" >/dev/null   # warm-up
LATEST=$(cast block-number --rpc-url "$RPC")
for i in $(seq 1 50); do
  HEX=$(printf '0x%x' $((LATEST - i)))
  TXS=$(cast block "$HEX" --rpc-url "$RPC" --json 2>/dev/null | jq -r '.transactions[]?')
  for t in $TXS; do
    case "$(cast receipt "$t" --rpc-url "$RPC" --json 2>/dev/null | jq -r '.to // ""')" in
      "$CONTRACT") echo "$t" ;;
    esac
  done
done
```

(For a real audit use the explorer's `/address/<addr>` page — much faster than the manual loop.)

### Workflow 3: estimate gas before re-sending

```bash
# If the call needs a `from` (it almost always does, for accurate estimation)
cast estimate <TO> "<SIG>" <ARGS...> \
  --rpc-url $RPC_URL \
  --from <SENDER>

# Multiply by 1.3 and re-send
GAS=$(cast estimate <TO> "<SIG>" <ARGS...> --rpc-url $RPC_URL --from <SENDER>)
GAS_LIMIT=$(( GAS * 13 / 10 ))
cast send <TO> "<SIG>" <ARGS...> --gas $GAS_LIMIT --rpc-url $RPC_URL --private-key $PRIVATE_KEY
```

## Command cheat sheet

| Command | Purpose |
|---|---|
| `cast tx <hash>` | Transaction details |
| `cast receipt <hash>` | Receipt with status + gas |
| `cast run <hash>` | Replay with full trace |
| `cast call <addr> "<sig>" <args>` | Simulate read-only call |
| `cast 4byte-decode <sel>` | Decode 4-byte selector to name |
| `cast estimate <addr> "<sig>" <args>` | Estimate gas for a write call |
| `cast gas-price` | Current network gas price |
| `cast chain-id` | Print the connected chain ID |
| `cast balance <addr>` | Native balance of an address |

## Curl-only fallback

If you can't install Foundry, every command above also works as raw `eth_*` JSON-RPC calls. The analyzer in `scripts/debug.sh` does exactly this with no `cast` dependency — read it as a reference implementation.
