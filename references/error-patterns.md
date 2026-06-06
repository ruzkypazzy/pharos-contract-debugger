# Error Patterns and Solutions

Comprehensive database of common smart-contract errors, their causes, and debugging solutions on Pharos Atlantic Testnet and Pacific Mainnet.

Every selector below is the **first 4 bytes of the returndata** when the call reverts. Use `cast 4byte-decode <selector>` to confirm.

## Standard Solidity errors

### Error(string) — generic string revert

- **Selector:** `0x08c379a0`
- **Cause:** Contract called `require(condition, "message")` or `revert("message")`.
- **Decode the message:** see [debug.md](debug.md#reading-errorstring-returns).
- **Fix:** Read the human message — it usually tells you exactly what condition failed.

### Panic(uint256) — runtime panic

- **Selector:** `0x4e487b71`
- **Cause:** Solidity 0.8+ built-in safety check failed.
- **Decode with:** `cast run <TX> --rpc-url $RPC_URL --debug`
- **Panic codes:**

| Code | Meaning | Typical cause |
|---|---|---|
| `0x01` | Assert failed | A `assert(x)` was false — usually a logic bug |
| `0x11` | Overflow / underflow | Solidity 0.7 or earlier, or unchecked arithmetic |
| `0x12` | Division / modulo by zero | Bad input to a math op |
| `0x21` | Invalid enum value | Casting an out-of-range uint to enum |
| `0x22` | Storage encoding error | Trying to access a non-existent storage array |
| `0x31` | Empty array pop | `.pop()` on an empty array |
| `0x32` | Array OOB | Index ≥ array.length |
| `0x41` | Memory too large | Allocating > 64 bytes in a memory-expanding op |
| `0x51` | Uninitialized function pointer | Internal-function-type variable never set |

## ERC20 errors

### insufficient allowance

- **Selector:** `0x13be252b`
- **Cause:** `transferFrom(from, to, amount)` was called with `allowance(from, msg.sender) < amount`.
- **Fix:**
  ```bash
  cast send <TOKEN> "approve(spender,amount)" \
    --rpc-url $RPC_URL --private-key $PRIVATE_KEY
  ```
  Some tokens (USDT-style) require resetting the allowance to 0 first:
  ```bash
  cast send <TOKEN> "approve(spender,0)"  ... # clear
  cast send <TOKEN> "approve(spender,N)"  ... # set new
  ```
  Prefer `increaseAllowance` / `decreaseAllowance` when the token supports them.

### insufficient balance

- **Selector:** `0xf4d758bb`
- **Cause:** Sender balance < requested amount.
- **Fix:**
  1. Verify the balance: `cast call <TOKEN> "balanceOf(address)(uint256)" <FROM> --rpc-url $RPC_URL`
  2. Verify the decimals match between the UI and the token: `cast call <TOKEN> "decimals()(uint8)" --rpc-url $RPC_URL`
  3. Top up the wallet or reduce the requested amount.

## Access control

### Ownable: caller is not the owner

- **Selector:** `0x118cdaa7`
- **Cause:** A function gated by `onlyOwner` was called from a non-owner EOA.
- **Fix:** Re-send from the owner EOA, or transfer ownership first: `cast send <CONTRACT> "transferOwnership(address)" <NEW_OWNER> --rpc-url $RPC_URL --private-key $OWNER_KEY`.

### AccessControl: account is missing role

- **Selector:** `0x2cf07b6c` (typed) or any 8-byte hash that hashes to a role constant
- **Cause:** The OpenZeppelin `AccessControl` check failed for the calling account.
- **Diagnose:**
  ```bash
  cast call <CONTRACT> "hasRole(bytes32,address)(bool)" <ROLE> <ACCOUNT> \
    --rpc-url $RPC_URL
  ```
- **Fix:** Grant the role: `cast send <CONTRACT> "grantRole(bytes32,address)" <ROLE> <ACCOUNT> --rpc-url $RPC_URL --private-key $ADMIN_KEY`.

### ECDSA: invalid signature / length

- **Selectors:** `0xe6c4247b` (invalid sig), `0xfb8f41b2` (invalid sig length)
- **Cause:** Signature in `ecrecover` was malformed, or the `v` byte was wrong.
- **Fix:** Almost always a *signer-side* bug — re-derive the message hash and signature with the same domain separator. For EIP-712 audits, decode the domain separator first.

## Uniswap / DEX specific

### UniswapV2: INSUFFICIENT_OUTPUT_AMOUNT

- **Selector:** `0x42301c23` (or `0x42301c23` followed by the amount as uint256)
- **Cause:** Slippage check on a UniswapV2-style swap failed.
- **Fix:** Either wait for a better price, or raise `amountOutMin` by lowering the user's slippage tolerance.

### UniswapV2: EXPIRED

- **Selector:** `0x08c379a0` with message containing `EXPIRED`
- **Cause:** Deadline on the swap passed.
- **Fix:** Re-submit with a current timestamp.

### UniswapV3: TooMuchRequested / TooLittleReceived

- **Selector:** `0x42301c23` or `0x3204506c`
- **Cause:** Same as V2 — slippage.
- **Fix:** Same as V2.

## Network errors

### Wrong chain

- **Selector:** N/A — the receipt is `null` because the tx was sent on a different chain.
- **Cause:** The wallet was on the wrong chain ID when the user submitted the tx.
- **Diagnose:** check the chain ID both at submission time and now:
  ```bash
  cast chain-id --rpc-url $RPC_URL
  ```
  Expected:
  - Atlantic Testnet: `688689`
  - Mainnet: `1672`
- **Fix:** Switch the wallet to the correct chain, re-sign, re-send.

### Tx not found

- **Cause:** The hash is from a different network than the one you're querying, or the tx hasn't been mined yet (try again in a few seconds).
- **Fix:**
  1. Confirm the chain ID
  2. Wait for inclusion and re-query
  3. If the user copied the hash wrong, ask them to re-paste

### RPC endpoint unreachable

- **Cause:** Endpoint downtime, region block, or rate limit.
- **Fix:**
  1. Try a different provider from `references/networks.json`
  2. Check Pharos status page
  3. Retry with exponential backoff

## Quick-fix cheat sheet

| Error | One-line fix |
|---|---|
| `insufficient balance` | Top up the wallet |
| `insufficient allowance` | `cast send <token> "approve(spender,amount)"` |
| `not owner` | Use the owner EOA |
| `missing role` | `grantRole(...)` from admin |
| `Out of gas` | Re-send with `gas_limit = gasUsed × 1.3` |
| `INSUFFICIENT_OUTPUT_AMOUNT` | Raise `amountOutMin` or wait for better price |
| `EXPIRED` | Re-send with a current timestamp |
| Wrong network | Switch wallet to chain 1672 or 688689 |
| Contract paused | Wait for the owner to call `unpause()` |

## Debug command cheat sheet

```bash
# Receipt + status
cast receipt <TX> --rpc-url $RPC_URL --json | jq '{status, gasUsed, from, to}'

# Full trace (shows the exact opcode that reverted)
cast run <TX> --rpc-url $RPC_URL --debug

# Estimate gas for a similar call
cast estimate <TO> "<sig>" <args> --rpc-url $RPC_URL --from <FROM>

# Read-only simulation
cast call <TO> "<sig>" <args> --rpc-url $RPC_URL --from <FROM>

# Decode a 4-byte selector
cast 4byte-decode 0x08c379a0

# Current chain + gas price
cast chain-id --rpc-url $RPC_URL
cast gas-price --rpc-url $RPC_URL
```
