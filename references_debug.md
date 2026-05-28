# Transaction Debugging Reference

Complete guide for debugging failed transactions on Pharos network using Foundry's `cast` commands.

## Transaction Debugging

### Basic Transaction Query

Get full transaction details including status, gas usage, and logs:

```bash
cast tx <TX_HASH> --rpc-url <RPC_URL>
```

### Get Transaction Receipt

Retrieve transaction receipt with execution status and gas details:

```bash
cast receipt <TX_HASH> --rpc-url <RPC_URL>
```

**Key Fields in Receipt:**

| Field | Description |
|-------|-------------|
| `status` | `0x1` = success, `0x0` = failed |
| `gasUsed` | Actual gas consumed |
| `effectiveGasPrice` | Gas price at execution |
| `logs` | Event logs (may contain error data) |

### Decode Transaction Failure

Check if transaction failed and extract failure reason:

```bash
# Check status (0 = failed, 1 = success)
cast receipt <TX_HASH> --rpc-url $RPC_URL | grep -E "status"

# Get full receipt as JSON for detailed analysis
cast receipt <TX_HASH> --rpc-url $RPC_URL --json
```

## Revert Reason Decoding

### Standard Error Decoding

Decode common Solidity error messages:

```bash
# Decode error signature from logs
cast 4byte <ERROR_SIGNATURE>

# Decode known standard errors
cast 4byte 0x08c379a0  # Error(string)
cast 4byte 0x4e487b71  # Panic(uint256)
```

### Revert String Decoding

Extract and decode revert reason strings:

```bash
# Parse from transaction trace
cast run <TX_HASH> --rpc-url $RPC_URL
```

## Gas Analysis

### Gas Limit Issues

Identify transactions that ran out of gas:

```bash
# Check gas used vs gas limit
cast receipt <TX_HASH> --rpc-url $RPC_URL --json | jq '{gasUsed: .gasUsed, gas: .gas}'
```

**Diagnosis Table:**

| Scenario | gasUsed | gas | Interpretation |
|----------|---------|-----|----------------|
| Out of gas | High (~gas) | Equal | Execution exceeded limit |
| Underpriced gas | Low | Normal | Gas price too low |
| Complex execution | Variable | High needed | Contract too complex |

### Gas Estimation

Estimate gas for successful transaction:

```bash
# Estimate gas for a call
cast estimate <CONTRACT_ADDRESS> "<FUNCTION_SIGNATURE>" <ARGS> --rpc-url $RPC_URL --from <FROM_ADDRESS>

# Get detailed gas breakdown
cast gas-price --rpc-url $RPC_URL
```

## Common Debugging Workflows

### Workflow 1: Basic Failure Analysis

```bash
# Step-by-step analysis
TX_HASH="0x..."
RPC_URL="https://rpc-testnet.pharosnetwork.xyz"

# Step 1: Get receipt
STATUS=$(cast receipt $TX_HASH --rpc-url $RPC_URL --json | jq -r '.status')
echo "Transaction Status: $STATUS"

# Step 2: If failed, get trace
if [ "$STATUS" = "0x0" ]; then
    echo "Transaction FAILED - Getting trace..."
    cast run $TX_HASH --rpc-url $RPC_URL --debug
fi
```

## Debug Commands Reference

| Command | Purpose |
|---------|---------|
| `cast tx <hash>` | Get transaction details |
| `cast receipt <hash>` | Get receipt with status |
| `cast run <hash>` | Replay transaction with trace |
| `cast call` | Simulate read-only call |
| `cast 4byte <sig>` | Decode function/error signature |
| `cast estimate` | Estimate gas for call |
| `cast gas-price` | Get current gas price |

## Network Configuration

```bash
# Atlantic Testnet
export RPC_URL="https://rpc-testnet.pharosnetwork.xyz"

# Mainnet
export RPC_URL="https://rpc.pharosnetwork.xyz"
```
