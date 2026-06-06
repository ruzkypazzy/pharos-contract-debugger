# Sample output

Real output from the analyzer. The hash below is a public Pacific-mainnet tx that **failed** — the demo prints the full failure path.

## Failed-tx case (real public mainnet tx)

```text
$ bash scripts/debug.sh 0x9606bcfd027b28e6783ca8b5fef1c3311476a1c30e5bf4464d0340a0d24ba7f7 --network mainnet

🔍 Pharos Contract Debugger
================================
Network: Pharos Pacific Ocean Mainnet
Chain:   1672 (PROS)
RPC:     https://rpc.pharos.xyz
TX:      0x9606bcfd027b28e6783ca8b5fef1c3311476a1c30e5bf4464d0340a0d24ba7f7

📡 Fetching transaction receipt...
📊 TRANSACTION DETAILS
----------------------
Block:    8527764
From:     0x67992af9a87f2d6a3062c333d8a06abbe3929438
To:       0x7a31dd32a880827477ab2bbeff47db188c896815
Gas:      207347 used / 950000 limit

❌ STATUS: FAILED

🔎 DIAGNOSIS
------------
⚠️  CAUSE: TRANSACTION REVERTED (no error data)
   Common causes on Pharos:
   • Insufficient token balance or allowance
   • Access control / missing role
   • Slippage exceeded on DEX swap
   • Contract paused or not initialized
   • Wrong function arguments

   To diagnose further:
     cast run 0x9606bcfd027b28e6783ca8b5fef1c3311476a1c30e5bf4464d0340a0d24ba7f7 --rpc-url https://rpc.pharos.xyz --debug

🔗 View on Explorer: https://www.pharosscan.xyz/tx/0x9606bcfd027b28e6783ca8b5fef1c3311476a1c30e5bf4464d0340a0d24ba7f7
📡 Network: Pharos Pacific Ocean Mainnet (chain 1672)
```

## Out-of-gas case (illustrative)

```text
$ bash scripts/debug.sh 0xOOG_TX_HERE --network mainnet

❌ STATUS: FAILED

🔎 DIAGNOSIS
------------
🚨 CAUSE: OUT OF GAS
   Gas used (300000) reached the gas limit (300000).

   FIX:
     cast estimate <TO> "<SIG>" <ARGS...> --rpc-url https://rpc.pharos.xyz --from 0xAbCd...
     # then re-send with gas_limit = estimate × 1.3
```

## Custom-error case (illustrative)

If the RPC node exposes the revert selector (e.g. via `cast receipt --json` on a Foundry-compatible node), the analyzer prints:

```text
❌ STATUS: FAILED

🔎 DIAGNOSIS
------------
⚠️  CAUSE: REVERTED WITH CUSTOM ERROR
   Selector: 0x13be252b
   Decoded:  ERC20: insufficient allowance

   To see the full error string (if it's Error(string)):
     cast 4byte-decode 0x13be252b
     # or replay with trace:
     cast run 0xYOUR_FAILED_TX_HERE --rpc-url https://rpc.pharos.xyz --debug
```

## Wrong-network case (illustrative)

```text
$ bash scripts/debug.sh 0xETHEREUM_TX_HERE --network mainnet

❌ Transaction not found on Pharos Pacific Ocean Mainnet.
   • Check the hash
   • Make sure it was sent to chain 1672
   • Try: bash scripts/debug.sh 0xETHEREUM_TX_HERE --network testnet
```

## Rich (cast + jq) output — `debug_demo.sh`

With `cast` and `jq` installed, the demo script produces a richer report that includes the called function name (decoded from the tx's first 4 bytes):

```text
$ bash scripts/debug_demo.sh 0xYOUR_TX --network mainnet

======================================
  PHAROS CONTRACT DEBUGGER (rich)
======================================
 Network:  Pharos Pacific Ocean Mainnet (chain 1672)
 Currency: PROS
 RPC:      https://rpc.pharos.xyz
 TX:       0xYOUR_TX

--------------------------------------
 Sender:   0xAbCd...
 To:       0xTokenContract...
 Block:    8532001
 Gas:      51203 / 300000  (effective: 1000000000 wei)
--------------------------------------

RESULT: ❌ TRANSACTION FAILED

STEP 2: Identifying the cause...

--------------------------------------
 Revert selector: 0x13be252b
 Decoded name:    approve(address,uint256)
 Called:          0x095ea7b3  approve(address,uint256)
--------------------------------------

STEP 3: Likely cause & fix
 → ERC20: insufficient allowance.
   Call approve(spender, amount) first.

 Explorer: https://www.pharosscan.xyz/tx/0xYOUR_TX
 Network:  Pharos Pacific Ocean Mainnet (chain 1672)
======================================
```
