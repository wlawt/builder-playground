# Final Solution: Using minBaseFee with TIPS Builder

## The Core Issue

Your TIPS builder (based on Base) expects `minBaseFee` in Engine API payload attributes.
Standard rollup-boost (designed for OP Stack) doesn't send this field.

```
op-node → rollup-boost → TIPS Builder ❌
          ↓
   PayloadAttributes WITHOUT minBaseFee
```

## The Real Solution: Use Base's Infrastructure

Since you're building on Base's code (rblib branch from base/tips), you should use Base's infrastructure components that natively support `minBaseFee`.

### Option 1: Use Base's Node-Reth (RECOMMENDED)

Base has `node-reth` which includes Flashblocks and Base-specific extensions:

```bash
# In builder-playground/playground/components.go
# Replace OpGeth with Base's Reth implementation

type BaseReth struct {
    BuilderURL string
}

func (b *BaseReth) Run(service *Service, ctx *ExContext) {
    service.
        WithImage("ghcr.io/base/node-reth-dev").
        WithTag("main").
        WithArgs(
            "node",
            "--chain", "/data/l2-genesis.json",
            "--datadir", "/data_base_reth",
            "--authrpc.port", `{{Port "authrpc" 8551}}`,
            "--authrpc.addr", "0.0.0.0",
            "--authrpc.jwtsecret", "/data/jwtsecret",
            "--http",
            "--http.addr", "0.0.0.0",
            "--http.port", `{{Port "http" 8545}}`,
        ).
        WithArtifact("/data/jwtsecret", "jwtsecret").
        WithArtifact("/data/l2-genesis.json", "l2-genesis.json").
        WithVolume("data", "/data_base_reth")

    // If builder URL is specified, add it
    if b.BuilderURL != "" {
        service.WithArgs("--builder-url", b.BuilderURL)
    }
}
```

### Option 2: Modify Rollup-Boost to Support minBaseFee

Create a fork of rollup-boost that includes Base's extensions:

**Steps:**
1. Fork flashbots/rollup-boost
2. Modify `crates/rollup-boost/src/payload.rs`
3. Add `min_base_fee` field to PayloadAttributes
4. Ensure it's forwarded to the builder
5. Build custom Docker image
6. Use in builder-playground

**Code changes needed in rollup-boost:**

```rust
// In payload.rs
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct BasePayloadAttributes {
    #[serde(flatten)]
    pub base: PayloadAttributes,

    #[serde(rename = "minBaseFee", skip_serializing_if = "Option::is_none")]
    pub min_base_fee: Option<U256>,
}

// Update forwarding logic to use BasePayloadAttributes
```

### Option 3: Bypass Rollup-Boost Entirely

Configure op-node to use the TIPS builder directly via its built-in builder support.

**Check if op-node has builder flags:**
```bash
op-node --help | grep -i builder
```

If it does, you can skip rollup-boost:

```go
// In OpNode component
func (o *OpNode) Run(service *Service, ctx *ExContext) {
    args := []string{
        "--l1", Connect(o.L1Node, "http"),
        // ... other args ...
    }

    // If external builder configured
    if ctx.ExternalBuilder != "" {
        args = append(args,
            "--builder.enabled",
            "--builder.url", ctx.ExternalBuilder,
            "--builder.jwt-secret", "/data/jwtsecret",
        )
    }

    service.WithArgs(args...)
}
```

## Immediate Workaround: Make Your TIPS Builder Compatible

While we work on the infrastructure, make your TIPS builder accept BOTH formats:

```rust
// In your TIPS builder
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PayloadAttributes {
    pub timestamp: u64,
    pub prev_randao: B256,
    pub suggested_fee_recipient: Address,
    pub withdrawals: Option<Vec<Withdrawal>>,
    pub parent_beacon_block_root: Option<B256>,

    // Make it optional with a sensible default
    #[serde(rename = "minBaseFee", default = "default_min_base_fee")]
    pub min_base_fee: U256,
}

fn default_min_base_fee() -> U256 {
    U256::from(1_000_000_000u64) // 1 gwei
}
```

This way:
- ✅ Works with standard rollup-boost (uses default)
- ✅ Works with Base's infrastructure (uses provided value)
- ✅ Allows testing while you build proper infrastructure

## Recommended Path Forward

### Short Term (Today):
1. **Modify TIPS builder** to accept missing `minBaseFee` with a default value
2. Test with current builder-playground setup
3. Verify blocks are being built

### Medium Term (This Week):
1. **Check if Base has rollup-boost fork**
   - Search base-org and coinbase GitHub
   - Ask in Base developer channels
2. **Or use Base's node-reth** if it supports external builders

### Long Term (Production):
1. **Use Base's full stack** (node-reth + their tooling)
2. Or **contribute minBaseFee support** to upstream rollup-boost
3. Submit PR to flashbots/rollup-boost with Base compatibility

## Testing the Workaround

1. **In your TIPS builder**, make `minBaseFee` optional:
```rust
#[serde(default)]
pub min_base_fee: Option<U256>,
```

2. **Rebuild:**
```bash
cd /Users/williamlaw/src/opensource/tips
cargo build --release
```

3. **Restart TIPS builder** with the new binary

4. **Test with builder-playground:**
```bash
cd /Users/williamlaw/src/opensource/builder-playground
go run main.go cook opstack \
  --external-builder http://host.docker.internal:8561 \
  --external-builder-jwt /Users/williamlaw/src/opensource/tips/jwt.hex
```

5. **Verify:**
```bash
# Check TIPS builder logs - should now accept the requests
tail -f /path/to/tips/builder.log

# Should see:
# ✅ Received engine_forkchoiceUpdatedV3
# ✅ Building block (minBaseFee: default)
```

## Why This Happens

- **OP Stack**: Standard Optimism doesn't have dynamic base fees
- **Base**: Extended OP Stack with EIP-1559 style base fees via `minBaseFee`
- **Rollup-boost**: Designed for standard OP Stack, doesn't know about Base extensions
- **Your TIPS builder**: Based on Base code, expects Base features

## Next Steps

Choose one:

**A. Quick Fix (5 minutes):**
   - Make minBaseFee optional in TIPS builder
   - Test immediately

**B. Proper Fix (1-2 hours):**
   - Fork rollup-boost
   - Add minBaseFee support
   - Build custom image

**C. Base Infrastructure (depends on availability):**
   - Use Base's node-reth
   - Use Base's rollup-boost (if it exists)

I recommend **Option A** to unblock yourself, then move to **Option C** for production.
