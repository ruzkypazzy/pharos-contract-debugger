# Pharos Contract Debugger

A smart-contract debugging skill for the [Pharos Agent Center](https://www.pharos.xyz/agent-center). Paste in any failed transaction hash from **Pharos Atlantic Testnet** or **Pharos Pacific Ocean Mainnet** and the skill returns a plain-English diagnosis of what went wrong — out of gas, reverted with a custom error, wrong network, missing allowance — plus a concrete fix.

The skill is built on the **Foundry** toolchain. All RPC reads go through `cast`. No curl, no jq, no Python — just bash + `cast`.

## What it diagnoses

| Failure mode | How it's detected | Suggested fix |
|---|---|---|
| Out of gas | `gasUsed == gasLimit` (via `cast receipt`) | Re-send with `gas_limit = gasUsed × 1.3` |
| Reverted with custom error | Decodes the 4-byte selector | Surfaces the human-readable error name and a fix path |
| Reverted without a reason | `gasUsed < gasLimit` but no error data | Common causes list: balance, allowance, role, paused, args |
| Wrong network | `cast receipt` returns nothing | Reminds you to switch chain ID |
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

## Install

### 1. Install Foundry (the engine the skill is built on)

```bash
curl -L https://foundry.paradigm.xyz | bash
foundryup
```

Verify with `cast --version`. This gives you `cast`, `forge`, `anvil`, and `chisel` on your `$PATH`.

### 2. Install jq (used to parse JSON)

```bash
# macOS
brew install jq
# Debian/Ubuntu/Termux
apt install -y jq
# Alpine
apk add jq
```

Verify with `jq --version`.

### 3. Get the skill

```bash
git clone https://github.com/ruzkypazzy/pharos-contract-debugger
cd pharos-contract-debugger
chmod +x scripts/*.sh
```

That's it. No `pip install`, no `npm install`, no `forge build`, no compile. The skill is one or more bash scripts that use `cast` (from Foundry) for every RPC read. The `assets/networks.json` file already knows the Pharos Pacific Mainnet and Atlantic Testnet endpoints.
## Quick test (try it in 30 seconds)

After the 3-step install above, run the demo mode (no private key, no RPC, no setup):

```bash
bash scripts/debug.sh demo
```

You should see a printed report. The demo uses synthetic data, so it works offline.

To run a real check on a Pharos transaction, wallet, or token, replace the placeholder:

```bash
bash scripts/debug.sh 0xYOUR_TX_HASH --network mainnet
```

## Use in an AI agent (Claude Code / Codex / OpenClaw / Pharos Agent Center)

The skill ships with a `SKILL.md` that AI agents auto-load. Once installed in your agent, just ask in natural language — the agent will read `SKILL.md` and run the bash script for you.

```text
"Why did my Pharos tx 0xabc... fail?"
```

The agent will run `bash scripts/debug.sh demo` (or the live command with the address you gave) and read the result back to you.

### Install in your agent

**Option A — Pharos Agent Center** (one-line install):

```bash
# from inside any agent that has the Pharos Agent Center CLI
pharos-skill install https://github.com/ruzkypazzy/pharos-contract-debugger
```

**Option B — OpenClaw / Claude Code / Codex** (one-line via npm):

```bash
npx skills add https://github.com/ruzkypazzy/pharos-contract-debugger
```

**Option C — Manual install** (drop into your agent's skills directory):

```bash
# Clone the skill
git clone https://github.com/ruzkypazzy/pharos-contract-debugger
cd pharos-contract-debugger

# Claude Code: copy to ~/.claude/skills/
mkdir -p ~/.claude/skills/pharos-contract-debugger
cp -r . ~/.claude/skills/pharos-contract-debugger/

# Codex: copy to ~/.codex/skills/
mkdir -p ~/.codex/skills/pharos-contract-debugger
cp -r . ~/.codex/skills/pharos-contract-debugger/

# OpenClaw: copy to ~/.openclaw/skills/
mkdir -p ~/.openclaw/skills/pharos-contract-debugger
cp -r . ~/.openclaw/skills/pharos-contract-debugger/

# Then restart the agent — the skill will be auto-loaded.
```
## Requirements

- `bash` 4+
- [`cast`](https://book.getfoundry.sh/getting-started/installation) (installed with Foundry) — **required**, all RPC reads go through it

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


## Framework

| Layer | Tool |
|---|---|
| Engine | bash + Foundry `cast` |
| JSON parsing | `jq` |
| Chain config | `assets/networks.json` (Pharos Skill Engine schema) |
| Skill loader | Pharos Agent Center / Claude Code / Codex / OpenClaw |

The skill is a thin bash wrapper that calls `cast` for every RPC read. No contracts are deployed, no private keys required.

## Dependencies

| Dependency | Required? | Notes |
|---|---|---|
| `cast` (Foundry) | **Yes** | `curl -L https://foundry.paradigm.xyz \| bash && foundryup` |
| `jq` | **Yes** | `apt install -y jq` or `brew install jq` |
| `bash` ≥ 4.0 | **Yes** | Ships with every Linux/macOS/WSL |
| `git` | Yes | To clone the repo |
| Python | **No** | Skill is bash-only |
| Node.js | **No** | Skill is bash-only |

## Tests

```bash
bash tests/test_debug_smoke.sh
```

The test suite covers the engine's heuristics, the JSON output schema, and (when run with `cast` installed) a live RPC smoke test against Pharos Pacific Mainnet.

## Repository layout

```
.
├── README.md                  # this file
├── SKILL.md                   # Agent-side description (loaded by Claude/Codex/etc.)
├── scripts/
│   └── debug.sh          # bash + cast engine — the entire skill
├── assets/
│   └── networks.json          # Pharos Skill Engine network config
└── tests/
    └── test_*.sh              # bash smoke test
```
## License

MIT
