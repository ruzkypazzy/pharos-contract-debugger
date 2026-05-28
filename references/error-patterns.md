# Error Patterns and Solutions

Comprehensive database of common smart contract errors, their causes, and debugging solutions for Pharos network.

## Standard Solidity Errors

### ERC20 Errors

#### ERC20: insufficient balance

**Error Signature:** `0xf4d758bb`

**Description:** Address does not have enough tokens for transfer.

**Common Causes:**
- Account balance is lower than requested transfer amount
- Tokens were previously transferred or delegated
- Balance check in contract uses strict equality

**Solutions:**
1. Ensure wallet has sufficient balance before transfer
2. Check if tokens are locked or subject to transfer restrictions
3. Verify token decimals match between frontend and contract

---

#### ERC20: insufficient allowance

**Error Signature:** `0x13be252b`

**Description:** Token spender has not been approved for requested amount.

**Common Causes:**
- Missing or insufficient `approve()` call before `transferFrom()`
- Previous approval was used up
- Approval was set to 0 (some tokens require reset)

**Solutions:**
1. Call `approve(spender, amount)` with sufficient allowance
2. If token requires reset: first call `approve(spender, 0)`, then `approve(spender, amount)`
3. Use `increaseAllowance` or `decreaseAllowance` when available

---

### Access Control Errors

#### Ownable: caller is not the owner

**Description:** Function with `onlyOwner` modifier called by non-owner.

**Solutions:**
1. Call function from owner address
2. Transfer ownership to correct address
3. Check if function should have different access modifier

---

#### AccessControl: account is missing role

**Description:** Caller does not have required role for operation.

**Debugging Steps:**
```bash
# Check if address has role
cast call <CONTRACT> "hasRole(bytes32,address)(bool)" <ROLE_HASH> <ADDRESS> --rpc-url $RPC_URL
```

**Solutions:**
1. Grant required role to calling address
2. Use admin account to assign role
3. Check if operation requires specific role

---

## Math and Arithmetic Errors

### Panic: arithmetic underflow/overflow

**Error Signature:** `0x4e487b71` (Panic(uint256))

**Panic Codes:**

| Code | Description |
|------|-------------|
| 0x11 | Arithmetic overflow/underflow |
| 0x12 | Division by zero |
| 0x21 | Invalid enum value |
| 0x31 | Empty array pop |
| 0x32 | Array out of bounds |

**Solutions:**
1. Use SafeMath library (older Solidity)
2. Use newer Solidity version with built-in overflow checks (0.8+)
3. Add manual checks before arithmetic operations

---

## Transaction Gas Errors

### Out of gas

**Description:** Transaction execution consumed all provided gas.

**Debugging:**
```bash
# Check gas used vs gas limit
cast receipt <TX_HASH> --rpc-url $RPC_URL --json | jq '{gasUsed: .gasUsed, gas: .gas}'
```

**Solutions:**
1. Increase gas limit for transaction
2. Simplify transaction (reduce iterations, data size)
3. Split large operations into multiple transactions
4. Optimize contract gas usage

---

### Gas too low

**Description:** Provided gas limit too low for transaction.

**Solutions:**
1. Estimate gas with `cast estimate`
2. Add buffer (10-20%) to estimated gas
3. Check for unexpectedly large state changes

---

## Network-Specific Errors

### Wrong Chain

**Error:** Transaction fails with unexpected behavior

**Debugging:**
```bash
# Verify chain ID
cast chain-id --rpc-url $RPC_URL

# Expected values:
# - Atlantic Testnet: 1891
# - Mainnet: 1892
```

---

## Quick Reference Tables

### Error to Solution Mapping

| Error | Quick Solution |
|-------|----------------|
| Insufficient balance | Add more tokens to wallet |
| Insufficient allowance | Call approve() first |
| Not owner | Use owner wallet |
| Missing role | Grant role via admin |
| Out of gas | Increase gas limit |
| Wrong network | Switch to correct chain |
| Contract paused | Wait for unpause |

---

### Debug Command Cheat Sheet

```bash
# Get transaction receipt
cast receipt <TX_HASH> --rpc-url $RPC_URL

# Replay with trace
cast run <TX_HASH> --rpc-url $RPC_URL --debug

# Estimate gas
cast estimate <ADDR> "<sig>" <args> --rpc-url $RPC_URL

# Read contract
cast call <ADDR> "<sig>" <args> --rpc-url $RPC_URL

# Decode error
cast 4byte <ERROR_SELECTOR>

# Check balance
cast balance <ADDR> --rpc-url $RPC_URL

# Get chain ID
cast chain-id --rpc-url $RPC_URL
```
