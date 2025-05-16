# 🧾 Technical Specification – DIAMOND Token (Anchor Smart Contract)

- reduce stack usage,
- handle all checked math operations,
- log events with `emit!`,
- respect multisig-based authority verification.


Perform modularization and avoid code duplication. PDA constraints and seeds must be respected.

Main goal compile project to local without a errors

---

## 🎯 Goal

Create a token contract with:

- Limited emission
- Fixed mint price
- Built-in control logic (`pause`, `multisig`, `blacklist`)
- Premint capability
- Admin token burn (with refund)
- On-chain purchases via website
- Proof-of-Reserve support
- Optimized stack usage

---

## 🔧 Functions (Each must be implemented separately)

### 1. `mint_by_user`

- User pays USDT, USDC, SOL, or another token via TokenAccount (on the website).
- Fixed price: **0.8 USDT per token**
- Checks: amount >= MIN_PURCHASE_USDT
- Payment is converted to USDT and transferred to a **PDA vault** (on-chain reserve).
- Must verify: `decimals == 6` for USDT/USDC and for the token.

---

### 2. `admin_burn` *(⚠️ Heavy stack — must be optimized!)*

- Admin can burn tokens from premint or PDA vault.
- Returns equivalent value in USDT.
- Executable **only via SPL multisig (3 of 5)**.
- User does NOT call this directly (they sell via DEX or use `purchase_item`).

---

### 3. `pause / unpause`

- `pause()` blocks minting.
- `unpause()` can only be called **15 minutes after** the last `pause()`.
- Last pause timestamp is stored in `TokenState`.
- Only callable via SPL multisig (3 of 5).

---

### 4. `update_max_supply`

- Allows **decreasing** `MAX_SUPPLY` (never increase).
- Only via SPL multisig (3 of 5).

---

### 5. `add_to_blacklist / remove_from_blacklist`

- Only via SPL multisig (3 of 5).
- Adds/removes addresses from blacklist.
- Blacklisted users **cannot mint**.
- Can be used in `transfer_hook`.

---

### 6. `on_transfer_hook`

- Based on **SPL Token-2022** standard.
- Prevents token transfers **between blacklisted addresses**.

---

### 7. `purchase_item`

- User burn tokens (via website e-commerce) once buy jewelry.


---

## 📦 Token Supply

- `INITIAL_SUPPLY`: 8,000,000 tokens → assigned to admin or vault at init.
- `MAX_SUPPLY`: 100,000,000 tokens → hard limit, cannot be increased.
- `TOTAL_SUPPLY`: 
  - Increases via `mint_by_user`
  - Decreases via `admin_burn` or `purchase_item`
- Stored in `TokenState`

---

## 🔍 Proof-of-Reserve

All payments go to **on-chain PDA vault**.
Anyone can verify USDT balance on-chain.

---

## 💰 Fees

- Buy fee: **0%**
- Sell fee: **0%**

---

## 🛡 Security

- All calculations must use:
  - `checked_add`, `checked_sub`, `checked_mul`, `saturating_sub`
- Use `require!`, `require_keys_eq!` for validations
- Always validate: `decimals == 6`

---

## 📢 Logging

- Emit events (`emit!`) for: mint, burn, pause, unpause, blacklist changes, purchases.
- Use `msg!` for internal validation status messages.

---

## 🔄 Wert Integration & Instruction Encoding

### 🎯 Usage of Wert for Minting Only

Wert is used **only** for minting tokens by users on the website.  
It is **not used** in the e-commerce store.

When a user purchases an item in the online store — the token is **burned automatically** instead of being sent to a PDA or account.

---

### 🧱 Encoding Instruction Data

Solana programs do not use Ethereum-style ABI calls.  
Instead, each instruction must be manually serialized as a binary payload, matching the program's expected format (usually Borsh).

To send a transaction via Wert, `sc_input_data` must include:

- `program_id`: Program address
- `accounts`: List of accounts (with signer/writable flags)
- `data`: Serialized instruction arguments (e.g. function selector + args), Borsh-encoded and hex-formatted

#### Example JSON Instruction:
```json
{
  "program_id": "11111111111111111111111111111111",
  "accounts": [
    {
      "address": "BGCSawehjnxUDciqRCPfrXqzKvBeiTSe3mEtvTFC5d9q",
      "is_signer": true,
      "is_writable": true
    },
    {
      "address": "C8eRw3N4ysXgbqkjw4QmtT5ws5ByE9TYGsuepVMBkXCy",
      "is_signer": false,
      "is_writable": true
    }
  ],
  "data": "0200000000ca9a3b00000000"
}
```

This must then be serialized to a single-line string and hex-encoded (required by Wert SDK).  
You can verify this using: [https://magictool.ai/tool/category/hex/](https://magictool.ai/tool/category/hex/)

---

### 💰 SOL vs SPL Payment Instructions

If using **SOL**:
- Include a fund-holding account: `CYdZAb4i2oaz5CiAvwenMyUVm2DJdd2cWKsekKxxXCQX` (must sign)

If using **SPL tokens**, include:
- The token account holding funds
- The owner of that token account (must sign)

#### Token Account Example:
| Token | Token Account | Owner |
|-------|----------------|-------|
| USDC  | BBmpNSJGA5FUM3s8LmgE9ScPno6bELNoU1BPtJt2fsdq | e2LE43wB7WzR3B7ZxfEH1C9kTRSQYeNTU43RcuTMh1g |

---

### 📚 Cross-chain NFT Mentions (for context)
- Tezos:
  - Gen1 NFT mint
  - Secondary sale
  - Item purchase using $DOGA
- Concordium:
  - Custom entrypoint usage

