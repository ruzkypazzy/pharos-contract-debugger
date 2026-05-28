---
name: pharos-contract-debugger
description: >
  Debug and analyze failed onchain transactions on Pharos network. Invoke when user mentions "debug", "failed", "revert", "error", "transaction failed", "execution reverted", "debug transaction", "analyze failure", "why did my tx fail", "transaction reverted", "call failed", or needs help understanding why a smart contract transaction failed. This skill decodes revert reasons, identifies common error patterns, and provides actionable debugging suggestions. REQUIRED for any transaction debugging or failure analysis on Pharos Chain.
version: 0.1.0
requires:
  anyBins:
    - cast
---

# Pharos Contract Debugger

Developer toolkit for debugging failed transactions and analyzing contract execution failures on Pharos blockchain. Uses Foundry (`cast`) commands to decode revert reasons, identify error patterns, and provide actionable debugging solutions.

## Prerequisites

**Install Foundry** (MANDATORY before any debugging operation):

```bash
# Check if Foundry is installed
which cast

# If not found, install Foundry
curl -L https://foundry.paradigm.xyz | bash
source ~/.zshenv && foundryup

# Verify installation
cast --version
```

## Network Configuration

Network information is stored in `references/networks.json`. Read this file to get RPC URLs and chain configuration:

```bash
# Read network configuration
cat references/networks.json
```

**Default Network**: Atlantic testnet (used when not specified)

## Capability Index

| User Need | Capability | Detailed Instructions |
|-----------|------------|----------------------|
| Analyze failed transaction by hash | Transaction Debugging | → `references/debug.md#transaction-debugging` |
| Decode custom error messages | Revert Reason Decoding | → `references/debug.md#revert-reason-decoding` |
| Match error against known patterns | Error Pattern Matching | → `references/error-patterns.md` |
| Analyze gas-related failures | Gas Analysis | → `references/debug.md#gas-analysis` |
| Find solutions for common errors | Solution Database | → `references/error-patterns.md#solutions` |

## General Error Handling

| Error Scenario | CLI Error Signature | Handling |
|---------------|---------------------|----------|
| Invalid transaction hash | `invalid transaction hash` | Prompt to check hash format (0x + 64 hex characters) |
| Transaction not found | `transaction not found` | Transaction may not be indexed yet, try with block number |
| Invalid address format | `invalid address` | Prompt to check address format (0x + 40 hex characters) |
| RPC endpoint unreachable | `network error` | Verify RPC URL is correct and accessible |
| Missing network config | Configuration file not found | Use default Atlantic testnet RPC |

## Security Reminders

- **Transaction Hash Privacy**: Debug logs may expose sensitive transaction data. Never share debug output containing addresses or amounts in public channels.
- **Private Key Safety**: This skill only reads blockchain data. Never request private keys for debugging operations.
- **RPC Security**: Use official Pharos RPC endpoints only. Never use untrusted RPC providers.

## Usage Examples

### Example 1: Debug Transaction Failure

```
User: "Why did my transaction 0x1234...abcd fail?"
Agent: Load references/debug.md, section "Transaction Debugging"
```

### Example 2: Decode Revert Reason

```
User: "What does this error mean? execution reverted: ERC20: insufficient allowance"
Agent: Load references/error-patterns.md, search for "insufficient allowance"
```

### Example 3: Gas Analysis

```
User: "My transaction ran out of gas, help me debug"
Agent: Load references/debug.md, section "Gas Analysis"
```

### Example 4: Custom Error Decoding

```
User: "Decode this custom error: 0x12345678"
Agent: Use cast 4byte or ABI decoding to decode custom error
```
