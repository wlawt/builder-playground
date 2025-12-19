# Solution: MissingMinBaseFeeInPayloadAttributes Error

## The Problem

Your TIPS builder (based on Base's implementation) expects `minBaseFee` in Engine API payload attributes.
Standard rollup-boost doesn't send this Base-specific field, causing the error:

```
MissingMinBaseFeeInPayloadAttributes
```

## Understanding The Architecture

### Current (Not Working):
```
op-node → rollup-boost → TIPS Builder ❌
          (standard OP Stack,
           no minBaseFee field)
```

### What We Need:
```
op-node → TIPS Builder ✅
          (Base-compatible,
           includes minBaseFee)
```

## Solution Options

### Option 1: Make TIPS Builder Accept Missing minBaseFee (Recommended)

**In your TIPS builder code**, make `minBaseFee` optional in the payload attributes:

```rust
// Change from:
pub struct PayloadAttributes {
    pub timestamp: u64,
    pub prev_randao: B256,
    pub suggested_fee_recipient: Address,
    pub withdrawals: Vec<Withdrawal>,
    pub parent_beacon_block_root: Option<B256>,
    pub min_base_fee: U256,  // Required
}

// To:
pub struct PayloadAttributes {
    pub timestamp: u64,
    pub prev_randao: B256,
    pub suggested_fee_recipient: Address,
    pub withdrawals: Vec<Withdrawal>,
    pub parent_beacon_block_root: Option<B256>,
    #[serde(default)]  // ADD THIS
    pub min_base_fee: Option<U256>,  // Make optional
}
```

Then in your builder logic:
```rust
let min_base_fee = attributes.min_base_fee.unwrap_or(U256::ZERO);
```

This makes your TIPS builder compatible with both Base and standard OP Stack.

### Option 2: Don't Use Rollup-Boost

Rollup-boost is primarily for advanced features like Flashblocks. For basic external building, you don't need it.

**Modify builder-playground to skip rollup-boost** when using an external builder without Flashblocks.

#### Implementation:

Edit `playground/recipe_opstack.go` around line 130:

```go
elNode := "op-geth"
if o.externalBuilder != "" {
    // Only use rollup-boost if Flashblocks is enabled
    if o.flashblocks {
        elNode = "rollup-boost"
        // ... existing flashblocks setup ...
    } else {
        // For simple external builders, use the builder directly as the EL
        // This won't work because op-geth still needs to execute blocks
        // So we actually DO need rollup-boost or similar proxy
    }
}
```

**Wait, this won't work** because op-geth still needs to execute blocks. The builder only builds them.

### Option 3: Use Base's Rollup-Boost (If It Exists)

Check if Base has a fork of rollup-boost that supports `minBaseFee`:

```bash
# Search for Base's rollup-boost
git clone https://github.com/base-org/rollup-boost
# or
git clone https://github.com/coinbase/rollup-boost
```

If found, update `playground/components.go`:

```go
service.
    WithImage("ghcr.io/base-org/rollup-boost").  // Use Base's version
    WithTag("latest").
```

### Option 4: Patch Rollup-Boost Locally

Create a custom rollup-boost image that forwards `minBaseFee`:

1. Clone rollup-boost:
```bash
git clone https://github.com/flashbots/rollup-boost
cd rollup-boost
```

2. Find the payload attributes forwarding code
3. Add `minBaseFee` field
4. Build custom image:
```bash
docker build -t rollup-boost:base-compat .
```

5. Update builder-playground:
```go
service.
    WithImage("rollup-boost").
    WithTag("base-compat").
```

## Recommended Solution: Fix TIPS Builder

**The cleanest solution is Option 1**: Make `minBaseFee` optional in your TIPS builder.

This makes your builder compatible with:
- ✅ Standard OP Stack (no minBaseFee)
- ✅ Base (with minBaseFee)
- ✅ Works with standard rollup-boost
- ✅ Future-proof

### Steps:

1. **In your TIPS builder repository** (`/Users/williamlaw/src/opensource/tips`):

Find the `PayloadAttributes` struct (likely in `crates/builder/src/` or similar).

2. Make `min_base_fee` optional:
```rust
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PayloadAttributes {
    // ... other fields ...
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub min_base_fee: Option<U256>,
}
```

3. Update your builder logic to handle missing `minBaseFee`:
```rust
fn build_block(&self, attributes: PayloadAttributes) -> Result<Payload> {
    let base_fee = attributes.min_base_fee
        .unwrap_or_else(|| self.calculate_default_base_fee());

    // ... rest of building logic ...
}
```

4. Rebuild and restart your TIPS builder:
```bash
cd /Users/williamlaw/src/opensource/tips
cargo build --release
# Restart your builder
```

5. Test with builder-playground:
```bash
cd /Users/williamlaw/src/opensource/builder-playground
go run main.go cook opstack \
  --external-builder http://host.docker.internal:8561 \
  --external-builder-jwt /Users/williamlaw/src/opensource/tips/jwt.hex
```

## Verification

After making the fix, you should see in TIPS builder logs:

```
✅ INFO Received Engine API call method=engine_forkchoiceUpdatedV3
✅ INFO Payload attributes received (minBaseFee: None, using default)
✅ INFO Building block...
```

Instead of:
```
❌ ERROR MissingMinBaseFeeInPayloadAttributes
```

## Why This Happens

Base extended the OP Stack with `minBaseFee` for their custom fee market.
Standard OP Stack (and rollup-boost) doesn't know about this field.

Your TIPS builder, being based on Base's code, expects it.
Making it optional maintains compatibility with both ecosystems.

## Alternative: Use Op-geth Directly

If you want to avoid rollup-boost entirely, you could configure op-geth as the builder, but this loses the separation between execution and building. Not recommended.

## Sources

- [Flashbots Rollup-Boost](https://github.com/flashbots/rollup-boost)
- [Introducing Rollup-Boost](https://writings.flashbots.net/introducing-rollup-boost)
