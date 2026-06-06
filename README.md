# Pharos Contract Debugger

A smart-contract debugging skill for the [Pharos Agent Center](https://www.pharos.xyz/agent-center). Paste in any failed transaction hash from **Pharos Atlantic Testnet** or **Pharos Pacific Ocean Mainnet** and the skill returns a plain-English diagnosis of what went wrong — out of gas, reverted with a custom error, wrong network, missing allowance — plus a concrete fix.

The skill uses the standard Pharos toolchain (`cast` + `curl`) so it runs anywhere Foundry is installed and needs no extra dependencies.

## What it diagnoses

| Failure mode | How it's detected | Suggested fix |
|---|---|---|
| Out of gas | `gasUsed == gasLimit` on a failed tx | Re-send with `gas_limit = gasUsed × 1.3` |
| Reverted with custom error | Decodes the 4-byte selector via `cast 4byte` | Surfaces the human-readable error name and a fix path |
| Reverted without a reason | `gasUsed < gasLimit` but no error data | Common causes list: balance, allowance, role, paused, args |
| Wrong network | `eth_getTransactionReceipt` returns `null` | Reminds you to switch chain ID |
| Insufficient allowance | Detects `0x13be252b` selector | `cast send <token> "approve(spender,amount)"` template |
| Insufficient balance | Detects `0xf4d758bb` selector | Top-up suggestions + decimal sanity check |
| Panic(uint256) | Decodes `0x4e487b71` and the panic code | Maps to overflow / divide-by-zero / out-of-bounds |

## Networks

| Network | Chain ID | Native token | RPC | Explorer |
|---|---:|---|---|---|
| Pharos Atlantic Testnet | 688689 | PHRS | `https://atlantic.dplabs-internal.com` | https://atlantic.pharosscan.xyz |
| Pharos Pacific Ocean Mainnet | 1672 | PROS | `https://rpc.pharos.xyz` | https://www.pharosscan.xyz |

The skill defaults to **Atlantic Testnet** (matches the official `pharos-skill-engine` default). Pass `--network mainnet` to debug mainnet txs.

## Quick start

### One-shot debug

```bash
# Debug any tx hash on mainnet
bash scripts/debug.sh 0x9606bcfd027b28e6783ca8b5fef1c3311476a1c30e5bf4464d0340a0d24ba7f7 --network mainnet

# Debug a tx on Atlantic testnet
bash scripts/debug.sh 0xYOUR_TX_HASH --network testnet
```

### Zero-dependency demo

If you don't have a failed tx handy, the demo script uses a real mainnet tx so you can see the full report:

```bash
bash scripts/debug_demo.sh
```

### Via the agent (SKILL.md)

Just say:

> *"Why did my Pharos tx 0xabc... fail?"*

The agent will run the script and read the diagnosis back to you.

## Requirements

- `bash` 4+ and `curl`
- [`cast`](https://book.getfoundry.sh/getting-started/installation) (installed with Foundry) — only used by `debug_demo.sh` for the rich JSON output
- `jq` — only used by `debug_demo.sh`

`debug.sh` is the dependency-free fallback (pure curl + grep + bash arithmetic). `debug_demo.sh` is the prettier version that needs `cast` and `jq`.

## Repository layout

```
.
├── README.md
├── SKILL.md                       # Agent-side description (loaded by Claude/Codex/etc.)
├── references/
│   ├── networks.json              # Canonical network config (Atlantic + Pacific)
│   ├── debug.md                   # cast / curl walkthrough
│   └── error-patterns.md          # Selector → cause → fix table
├── scripts/
│   ├── debug.sh                   # Zero-dep analyzer (curl-only)
│   └── debug_demo.sh              # Richer output using cast + jq
└── examples/
    └── sample-output.md           # What a real run looks like
```

## License

MIT
