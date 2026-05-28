# Pharos Contract Debugger

A comprehensive debugging skill for the Pharos Agent Centre that helps developers analyze failed transactions, decode revert reasons, and identify solutions for common smart contract errors on Pharos blockchain.

## Overview

The **Pharos Contract Debugger** is an AI-powered debugging toolkit designed to work with the Pharos Agent Centre. It provides structured debugging workflows, error pattern matching, and actionable solutions for developers working with smart contracts on Pharos network.

### Features

- **Transaction Debugging**: Analyze failed transactions by hash
- **Revert Reason Decoding**: Parse and explain Solidity error messages
- **Error Pattern Matching**: Match errors against known patterns
- **Gas Analysis**: Identify gas-related failures and optimization tips
- **Solution Database**: Comprehensive solutions for common errors
- **Interactive Debugging**: Step-by-step debugging workflows

## Installation

### For OpenClaw

```bash
openclaw skills add https://github.com/YOUR_GITHUB/pharos-contract-debugger
```

### For Claude Code

```bash
# Copy skill to Claude Code skills directory
mkdir -p ~/.claude/skills
cp -r . ~/.claude/skills/pharos-contract-debugger
```

### For Codex

```bash
# Copy skill to Codex skills directory
mkdir -p ~/.codex/skills
cp -r . ~/.codex/skills/pharos-contract-debugger
```

### Manual Installation

```bash
# Clone repository
git clone https://github.com/YOUR_GITHUB/pharos-contract-debugger.git

# Verify structure
ls -la pharos-contract-debugger/
# Should show: SKILL.md, references/, README.md
```

## Prerequisites

### Required Tools

1. **Foundry** (Required)

   ```bash
   # Install Foundry
   curl -L https://foundry.paradigm.xyz | bash
   source ~/.zshenv && foundryup

   # Verify installation
   cast --version
   ```

2. **jq** (Recommended for JSON parsing)

   ```bash
   # macOS
   brew install jq

   # Ubuntu/Debian
   sudo apt-get install jq

   # Verify
   jq --version
   ```

### Network Configuration

The skill includes pre-configured network settings:

| Network | Chain ID | RPC URL |
|---------|----------|---------|
| Atlantic Testnet | 1891 | https://rpc-testnet.pharosnetwork.xyz |
| Mainnet | 1892 | https://rpc.pharosnetwork.xyz |

## Usage

### Basic Usage

The skill is automatically invoked when you describe debugging needs naturally:

```
User: "Why did my transaction 0x1234...abcd fail?"
User: "Debug this error: execution reverted"
User: "Help me understand why my transfer failed"
User: "Analyze this failed transaction"
```

### Command Reference

#### Debug Transaction by Hash

```bash
# Basic transaction debugging
cast tx <TX_HASH> --rpc-url https://rpc-testnet.pharosnetwork.xyz

# Get receipt with full details
cast receipt <TX_HASH> --rpc-url https://rpc-testnet.pharosnetwork.xyz --json | jq '.'
```

#### Decode Failed Transaction

```bash
# Replay transaction with trace
cast run <TX_HASH> --rpc-url https://rpc-testnet.pharosnetwork.xyz --debug
```

#### Check Balance and Allowance

```bash
# Check token balance
cast call <TOKEN_ADDRESS> "balanceOf(address)(uint256)" <WALLET_ADDRESS> --rpc-url $RPC_URL

# Check allowance
cast call <TOKEN_ADDRESS> "allowance(address,address)(uint256)" <OWNER> <SPENDER> --rpc-url $RPC_URL
```

#### Estimate Gas

```bash
cast estimate <CONTRACT> "<FUNCTION_SIGNATURE>" <ARGS> --rpc-url $RPC_URL --from <ADDRESS>
```

## File Structure

```
pharos-contract-debugger/
├── SKILL.md                      # Main skill definition
├── README.md                     # This file
└── references/
    ├── networks.json             # Network configuration
    ├── debug.md                  # Debugging reference guide
    └── error-patterns.md         # Error patterns and solutions
```

## Error Coverage

### ERC Standards

- [x] ERC20: Balance and allowance errors
- [x] ERC721: Token ownership and transfer errors
- [x] ERC1155: Multi-token errors
- [x] ERC165: Interface support errors

### Access Control

- [x] Ownable: Owner-only function errors
- [x] AccessControl: Role-based access errors
- [x] Permissioned: Custom permission errors

### Security

- [x] ReentrancyGuard: Reentrancy detection
- [x] Pausable: Contract pause errors
- [x] Reentrancy: State manipulation detection

### Arithmetic

- [x] Overflow/Underflow (Solidity 0.8+)
- [x] Division by zero
- [x] Invalid enum values
- [x] Array out of bounds

### Network

- [x] Wrong network errors
- [x] RPC connection issues
- [x] Gas estimation failures

## License

MIT License - Free to use, modify, and redistribute.

---

**Version:** 0.1.0
**Built for:** Pharos Agent Centre Skill Builder Campaign
