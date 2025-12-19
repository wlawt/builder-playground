# Summary of Changes: External TIPS Builder Integration

## What Was Done

Modified builder-playground to support connecting the sequencer to an external TIPS builder via Engine API with custom JWT authentication.

## Files Changed

### 1. `playground/recipe_opstack.go`
**Added:**
- `externalBuilderJWT` field to `OpRecipe` struct (line 16)
- `--external-builder-jwt` flag to `Flags()` method (line 55)
- JWT configuration in `Artifacts()` method (lines 70-72)

**Purpose:** Allow users to specify a custom JWT secret file for external builder authentication.

### 2. `playground/artifacts.go`
**Added:**
- `customJWT` field to `ArtifactsBuilder` struct (line 68)
- `CustomJWT()` method (lines 105-108)
- JWT file reading logic in artifact generation (lines 244-253)

**Purpose:** Read JWT secret from custom file and use it for all service authentication.

### 3. `scripts/verify-external-builder.sh` (new file)
**Purpose:** Automated verification script to check:
- Rollup-boost container status
- Connectivity to external builder
- Recent logs and configuration

### 4. `TIPS_BUILDER_SETUP.md` (new file)
**Purpose:** Comprehensive documentation covering:
- Architecture overview
- Configuration details
- Step-by-step usage guide
- Troubleshooting guide
- Port reference
- Expected log output

### 5. `QUICK_START_TIPS.md` (new file)
**Purpose:** Quick reference with:
- Exact commands to run
- Configuration explanation
- Verification checklist
- Common troubleshooting

## The Exact Command

```bash
go run main.go cook opstack \
  --external-builder http://host.docker.internal:8561 \
  --external-builder-jwt /Users/williamlaw/src/opensource/tips/jwt.hex
```

## How It Works

### Before (Without External Builder)
```
Sequencer → Builds blocks internally → Proposes blocks
```

### After (With External TIPS Builder)
```
Sequencer → Rollup-boost → TIPS Builder (8561) → Returns payload → Proposes blocks
            (JWT Auth)      (Builds with UserOps)
```

## Key Technical Details

### 1. Network Configuration
- Uses `http://host.docker.internal:8561` (not `localhost`)
- Allows Docker containers to reach host machine services
- TIPS builder must listen on `0.0.0.0:8561`

### 2. JWT Authentication
- JWT secret: `0x2053bbf613d005202d3215c33c6ead941b821fb85f695c8e87c5c5649e70974c`
- Stored at: `/Users/williamlaw/src/opensource/tips/jwt.hex`
- Shared between rollup-boost and TIPS builder
- Automatically loaded and used by all services

### 3. Rollup-boost Configuration
Automatically configured with:
```bash
--builder-url http://host.docker.internal:8561
--builder-jwt-path /data/jwtsecret
--l2-url http://op-geth:8551
--l2-jwt-path /data/jwtsecret
```

## Engine API Flow

1. **op-node** sends `engine_forkchoiceUpdatedV3` to **rollup-boost** (port 8551)
2. **rollup-boost** authenticates with JWT and forwards to **TIPS builder** (port 8561)
3. **TIPS builder** builds block with UserOps
4. **op-node** requests `engine_getPayloadV3`
5. **rollup-boost** forwards to **TIPS builder**
6. **TIPS builder** returns built payload
7. **rollup-boost** returns to **op-node**
8. **op-node** proposes block

## Verification Steps

### 1. Check Container Running
```bash
docker ps | grep rollup-boost
```

### 2. Run Verification Script
```bash
./scripts/verify-external-builder.sh
```

### 3. Watch Logs
```bash
docker logs -f $(docker ps -q -f name=rollup-boost)
```

### 4. Send Test Transaction
```bash
cast send 0x0000000000000000000000000000000000000000 \
  --value 0.01ether \
  --rpc-url http://localhost:8547 \
  --private-key 0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d
```

## Expected Behavior

### TIPS Builder Logs Should Show:
```
INFO Received Engine API call method=engine_forkchoiceUpdatedV3
INFO Building block with payload attributes
INFO Received Engine API call method=engine_getPayloadV3
INFO Returning built payload
```

### Rollup-boost Logs Should Show:
```
INFO Builder URL: http://host.docker.internal:8561
INFO Forwarding engine_forkchoiceUpdatedV3 to builder
INFO Response from builder: 200 OK
```

## Backward Compatibility

All existing functionality remains unchanged:
- Default JWT still works: `04592280e1778419b7aa954d43871cb2cfb2ebda754fb735e8adeb293a88f9bf`
- External builder URLs work: `--external-builder http://host.docker.internal:4444`
- All other flags and features unchanged

## Testing Status

- ✅ Code compiles successfully
- ✅ Backward compatibility maintained
- ✅ JWT loading logic tested
- ✅ Documentation complete

## Next Steps for User

1. Ensure TIPS builder is running on `http://localhost:8561`
2. Verify JWT file exists at `/Users/williamlaw/src/opensource/tips/jwt.hex`
3. Run builder-playground with the command above
4. Run verification script
5. Send test transaction
6. Monitor TIPS builder logs for Engine API calls

## Troubleshooting Resources

- **Quick Start:** `QUICK_START_TIPS.md`
- **Full Guide:** `TIPS_BUILDER_SETUP.md`
- **Verification:** `./scripts/verify-external-builder.sh`
- **Logs:** `docker logs -f $(docker ps -q -f name=rollup-boost)`
