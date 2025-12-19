# Configure Sequencer to Use External TIPS Builder

This guide shows how to configure the op-geth sequencer in builder-playground to use an external TIPS builder for block building via the Engine API.

## Architecture

```
Transaction → Sequencer (op-node)
                  ↓
            Rollup-boost (Engine API Proxy)
                  ↓
         TIPS Builder (localhost:8561)
                  ↓ (builds block)
            Rollup-boost
                  ↓ (returns payload)
         Sequencer (includes in chain)
```

## Prerequisites

### 1. TIPS Builder Running

Your TIPS builder must be running with:
- **Engine API**: `http://localhost:8561`
- **JWT Secret**: In file at `/Users/williamlaw/src/opensource/tips/jwt.hex`
- **Listening on**: `0.0.0.0` (not just `127.0.0.1`)

Example TIPS builder configuration:
```bash
--authrpc.addr=0.0.0.0
--authrpc.port=8561
--authrpc.jwtsecret=./jwt.hex
--rollup.sequencer-http=http://localhost:8547
```

### 2. JWT Secret File

Your JWT secret file should contain:
```bash
# /Users/williamlaw/src/opensource/tips/jwt.hex
0x2053bbf613d005202d3215c33c6ead941b821fb85f695c8e87c5c5649e70974c
```

## Configuration Files Modified

### 1. `playground/recipe_opstack.go`
- Added `--external-builder-jwt` flag to specify custom JWT secret path
- Updated `Artifacts()` to use custom JWT when provided

### 2. `playground/artifacts.go`
- Added `customJWT` field to `ArtifactsBuilder`
- Added `CustomJWT()` method to set custom JWT path
- Modified artifact generation to read and use custom JWT file

### 3. `playground/components.go`
- RollupBoost component already configured to proxy Engine API calls
- Uses shared JWT secret for both L2 and builder authentication

## Usage

### Step 1: Run builder-playground with your TIPS builder

```bash
cd /Users/williamlaw/src/opensource/builder-playground

go run main.go cook opstack \
  --external-builder http://host.docker.internal:8561 \
  --external-builder-jwt /Users/williamlaw/src/opensource/tips/jwt.hex
```

**Important Notes:**
- Use `http://host.docker.internal:8561` (not `localhost`) because rollup-boost runs inside Docker
- The `--external-builder-jwt` flag tells builder-playground to use your TIPS builder's JWT secret
- This ensures the JWT secret matches between rollup-boost and your TIPS builder

### Step 2: Verify Connection

In another terminal:

```bash
./scripts/verify-external-builder.sh
```

This will:
- Check if rollup-boost is running
- Verify connectivity to your TIPS builder
- Show recent logs

### Step 3: Watch TIPS Builder Logs

In your TIPS builder terminal, you should see Engine API calls:

```
INFO Received Engine API call method=engine_forkchoiceUpdatedV3
INFO Building block with payload attributes
INFO Received Engine API call method=engine_getPayloadV3
INFO Returning built payload
```

### Step 4: Send Test Transaction

```bash
cast send 0x0000000000000000000000000000000000000000 \
  --value 0.01ether \
  --rpc-url http://localhost:8547 \
  --private-key 0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d
```

## How It Works

### 1. Rollup-boost Configuration

When you run with `--external-builder`, builder-playground deploys rollup-boost with:

```bash
--rpc-host 0.0.0.0
--rpc-port 8551                              # Listens for op-node requests
--l2-jwt-path /data/jwtsecret                # JWT for L2 (op-geth)
--l2-url http://op-geth:8551                 # L2 sequencer
--builder-jwt-path /data/jwtsecret           # JWT for builder (TIPS)
--builder-url http://host.docker.internal:8561  # Your TIPS builder
```

### 2. JWT Secret Handling

- Builder-playground reads your JWT file: `/Users/williamlaw/src/opensource/tips/jwt.hex`
- Extracts the secret: `2053bbf613d005202d3215c33c6ead941b821fb85f695c8e87c5c5649e70974c`
- Writes it to artifacts as `jwtsecret`
- Rollup-boost uses this to authenticate with your TIPS builder

### 3. Engine API Flow

1. **op-node** (sequencer consensus) sends `engine_forkchoiceUpdatedV3` to **rollup-boost**
2. **rollup-boost** forwards to **TIPS builder** at `http://host.docker.internal:8561`
3. **TIPS builder** builds block with UserOps
4. **op-node** requests payload via `engine_getPayloadV3`
5. **rollup-boost** forwards to **TIPS builder**
6. **TIPS builder** returns built payload
7. **rollup-boost** returns payload to **op-node**
8. **op-node** proposes block to network

## Verification Checklist

- [ ] TIPS builder is running on `http://localhost:8561`
- [ ] TIPS builder is listening on `0.0.0.0:8561` (not just `127.0.0.1`)
- [ ] JWT secret file exists at `/Users/williamlaw/src/opensource/tips/jwt.hex`
- [ ] builder-playground started with `--external-builder` and `--external-builder-jwt` flags
- [ ] Rollup-boost container is running: `docker ps | grep rollup-boost`
- [ ] Rollup-boost logs show connection to builder
- [ ] TIPS builder logs show incoming Engine API calls
- [ ] Test transaction successfully included in block

## Troubleshooting

### Issue: "Cannot reach external builder"

**Solution:**
```bash
# Check TIPS builder is listening on all interfaces
netstat -an | grep 8561

# Should show:
# tcp4  0  0  *.8561  *.*  LISTEN

# If it shows 127.0.0.1:8561, restart TIPS builder with:
--authrpc.addr=0.0.0.0
```

### Issue: "JWT verification failed"

**Solution:**
```bash
# Verify JWT secret matches
cat /Users/williamlaw/src/opensource/tips/jwt.hex
cat ~/.playground/devnet/jwtsecret

# They should both contain:
# 2053bbf613d005202d3215c33c6ead941b821fb85f695c8e87c5c5649e70974c
```

### Issue: "Connection refused to host.docker.internal:8561"

**Solution:**
- Ensure TIPS builder is running before starting builder-playground
- On Linux, `host.docker.internal` might not work - use `--network host` or the host's IP address
- On macOS/Windows, `host.docker.internal` should work automatically

### Issue: "Blocks not being built by TIPS builder"

**Solution:**
```bash
# Check rollup-boost logs
docker logs -f $(docker ps -q -f name=rollup-boost)

# Look for:
# - "forwarding to builder"
# - HTTP request logs to the builder URL
# - Response status codes (should be 200)

# Check TIPS builder logs for Engine API calls
# Should see engine_forkchoiceUpdatedV3 and engine_getPayloadV3
```

## Port Reference

| Service | Port | Description |
|---------|------|-------------|
| TIPS Builder Engine API | 8561 | Receives Engine API calls from rollup-boost |
| TIPS Builder RPC | 2222 | Regular RPC endpoint (not used by sequencer) |
| Sequencer RPC | 8547 | Sequencer RPC (receives user transactions) |
| Rollup-boost | 8551 | Engine API proxy (inside Docker) |

## Command Reference

### Start with External TIPS Builder
```bash
go run main.go cook opstack \
  --external-builder http://host.docker.internal:8561 \
  --external-builder-jwt /Users/williamlaw/src/opensource/tips/jwt.hex
```

### Verify Connection
```bash
./scripts/verify-external-builder.sh
```

### Watch Rollup-boost Logs
```bash
docker logs -f $(docker ps -q -f name=rollup-boost)
```

### Send Test Transaction
```bash
cast send 0x0000000000000000000000000000000000000000 \
  --value 0.01ether \
  --rpc-url http://localhost:8547 \
  --private-key 0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d
```

### Check Block Was Built
```bash
cast block latest --rpc-url http://localhost:8547
```

## Expected Log Output

### Rollup-boost
```
INFO Starting rollup-boost
INFO L2 URL: http://op-geth:8551
INFO Builder URL: http://host.docker.internal:8561
INFO Forwarding engine_forkchoiceUpdatedV3 to builder
INFO Response from builder: 200 OK
```

### TIPS Builder
```
INFO Received Engine API call method=engine_forkchoiceUpdatedV3
INFO Payload attributes received
INFO Building block with UserOps
INFO Received Engine API call method=engine_getPayloadV3
INFO Returning payload with 5 UserOps bundled
```

### Op-node (Sequencer)
```
INFO Block proposed block=12345 builder=external
INFO Block included in chain
```
