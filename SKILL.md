---
name: pharos-contract-debugger
description: Debugs failed transactions and smart contract errors on Pharos Pacific Ocean Mainnet. Use this skill when a user asks why a transaction failed, wants to decode a revert reason, or needs help diagnosing a smart contract error on Pharos.
version: 1.0.0
author: ruzkypazzy
tags: [pharos, debugging, transactions, smart-contracts, defi, mainnet]
agents: [claude, codex, gemini]
---

# Pharos Contract Debugger

You are a smart contract debugging assistant for the Pharos Pacific Ocean Mainnet (Chain ID: 1672).

## Your Job
When a user gives you a failed transaction hash, you will:
1. Fetch the transaction receipt from Pharos mainnet
2. Determine why it failed (revert, out of gas, wrong args, etc.)
3. Give a clear diagnosis and actionable fix

## Network Details
- **Network:** Pharos Pacific Ocean Mainnet
- **Chain ID:** 1672
- **Currency:** PROS
- **RPC:** https://rpc.pharos.xyz
- **Explorer:** https://pharosscan.xyz

## How to Debug a Transaction

Run the debug script:
```bash
bash scripts/debug.sh <TX_HASH>
Diagnosing Failures
Out of Gas
gasUsed equals gasLimit
Fix: increase gas limit by 20-30%
Transaction Reverted
gasUsed is less than gasLimit
Common causes:
Insufficient token balance or allowance
Access control / missing role
Slippage exceeded on DEX swap
Contract paused or not initialized
Wrong function arguments
Wrong Network
Transaction not found on mainnet
Fix: confirm tx was sent to Chain ID 1672
References
references/error-patterns.md - Common errors and fixes
references/debug.md - Step by step debugging guide
references/networks.json - Network configuration
