# Pharos Contract Debugger

A smart contract debugging skill for the Pharos Agent Centre. Analyzes failed transactions on Pharos Pacific Ocean Mainnet and provides clear diagnosis and fixes.

## Network
- Network: Pharos Pacific Ocean Mainnet
- Chain ID: 1672
- Currency: PROS
- RPC: https://rpc.pharos.xyz
- Explorer: https://pharosscan.xyz

## Prerequisites
- Linux or Mac terminal
- curl (pre-installed on most systems)
- No npm, no Node.js, no Foundry required

## Usage
Clone the repo and run the debug script:
    git clone https://github.com/ruzkypazzy/pharos-contract-debugger
    cd pharos-contract-debugger
    bash scripts/debug.sh TX_HASH

## Example
    bash scripts/debug.sh 0x9606bcfd027b28e6783ca8b5fef1c3311476a1c30e5bf4464d0340a0d24ba7f7

## What It Does
- Fetches transaction from Pharos mainnet live via RPC
- Detects: success, revert, out of gas, wrong network
- Shows block number, gas used, contract address
- Gives actionable fix for each failure type
- Links directly to Pharosscan explorer

## License
MIT
