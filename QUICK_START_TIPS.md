# Quick Start: Connect Sequencer to TIPS Builder

## The Exact Commands You Need

### 1. Run builder-playground with your TIPS builder

```bash
cd /Users/williamlaw/src/opensource/builder-playground

go run main.go cook opstack \
  --external-builder http://host.docker.internal:8561 \
  --external-builder-jwt /Users/williamlaw/src/opensource/tips/jwt.hex
```

### 2. Verify it's working

```bash
# In another terminal
./scripts/verify-external-builder.sh
```

### 3. Watch the logs

```bash
# Watch rollup-boost logs
docker logs -f $(docker ps -q -f name=rollup-boost)
```

You should see Engine API calls being forwarded to your TIPS builder.

### 4. Send a test transaction

```bash
cast send 0x0000000000000000000000000000000000000000 \
  --value 0.01ether \
  --rpc-url http://localhost:8547 \
  --private-key 0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d
```

## What Changed

### Files Modified

1. **`playground/recipe_opstack.go`**
   - Added `--external-builder-jwt` flag
   - Pass custom JWT to artifacts builder

2. **`playground/artifacts.go`**
   - Added `CustomJWT()` method
   - Read JWT from file and use it for all services

3. **`scripts/verify-external-builder.sh`** (new)
   - Verification script to check connection

4. **`TIPS_BUILDER_SETUP.md`** (new)
   - Full documentation

## How It Works

```
┌─────────────────┐
│  Your Transaction│
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  Sequencer      │ http://localhost:8547
│  (op-node)      │
└────────┬────────┘
         │ engine_forkchoiceUpdatedV3
         ▼
┌─────────────────┐
│  Rollup-boost   │ (Inside Docker)
│  (Proxy)        │ Authenticates with JWT
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  TIPS Builder   │ http://host.docker.internal:8561
│  (Your Code)    │ Builds block with UserOps
└────────┬────────┘
         │
         ▼ Returns payload
┌─────────────────┐
│  Block Included │
└─────────────────┘
```

## Configuration Explained

### `--external-builder http://host.docker.internal:8561`
- Points rollup-boost to your TIPS builder's Engine API
- Uses `host.docker.internal` because rollup-boost runs in Docker
- Your TIPS builder sees this as coming from `localhost:8561`

### `--external-builder-jwt /Users/williamlaw/src/opensource/tips/jwt.hex`
- Tells builder-playground to use your JWT secret
- JWT content: `0x2053bbf613d005202d3215c33c6ead941b821fb85f695c8e87c5c5649e70974c`
- Ensures authentication succeeds between rollup-boost and TIPS builder

## Verification Checklist

After running the commands, verify:

- [ ] Rollup-boost container is running
  ```bash
  docker ps | grep rollup-boost
  ```

- [ ] TIPS builder receives Engine API calls
  Check your TIPS builder logs for:
  ```
  engine_forkchoiceUpdatedV3
  engine_getPayloadV3
  ```

- [ ] Transactions go through the builder
  Send a transaction and check it appears in a block built by TIPS

## Troubleshooting

### "Connection refused to host.docker.internal:8561"

**Cause:** TIPS builder not listening on all interfaces

**Fix:**
```bash
# Make sure TIPS builder uses:
--authrpc.addr=0.0.0.0  # Not 127.0.0.1
```

### "JWT verification failed"

**Cause:** JWT secret mismatch

**Fix:**
```bash
# Check JWT matches
cat /Users/williamlaw/src/opensource/tips/jwt.hex
# Should contain: 0x2053bbf613d005202d3215c33c6ead941b821fb85f695c8e87c5c5649e70974c
```

### "No Engine API calls in TIPS builder"

**Cause:** Rollup-boost not forwarding to builder

**Fix:**
```bash
# Check rollup-boost logs
docker logs $(docker ps -q -f name=rollup-boost) | grep -i builder

# Should show:
# Builder URL: http://host.docker.internal:8561
```

## Success Indicators

When everything is working, you'll see:

**1. Rollup-boost logs:**
```
Forwarding engine_forkchoiceUpdatedV3 to builder
Response from builder: 200 OK
```

**2. TIPS builder logs:**
```
Received Engine API call method=engine_forkchoiceUpdatedV3
Building block with UserOps
Received Engine API call method=engine_getPayloadV3
```

**3. Transaction included:**
```bash
cast tx <TXHASH> --rpc-url http://localhost:8547
# Shows transaction in a block
```

## Next Steps

Once connected, test the full flow:

1. **Send UserOps to TIPS ingress RPC** → `http://localhost:2222`
2. **UserOps processed** → TIPS builder validates and bundles
3. **Block building** → Sequencer requests payload from TIPS builder
4. **Block proposed** → TIPS builder returns payload with UserOps
5. **Check UI** → UserOps visible in block explorer

For full documentation, see: `TIPS_BUILDER_SETUP.md`
