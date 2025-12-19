#!/bin/bash
set -e

# Script to verify external builder connection
# Usage: ./verify-external-builder.sh

echo "🔍 Verifying External Builder Connection..."
echo ""

# Check if rollup-boost is running
if ! docker ps | grep -q rollup-boost; then
    echo "❌ rollup-boost container is not running"
    echo "   Make sure you started builder-playground with --external-builder flag"
    exit 1
fi

echo "✅ rollup-boost container is running"

# Get rollup-boost container ID
ROLLUP_BOOST_ID=$(docker ps -q -f name=rollup-boost)

# Check rollup-boost logs for builder URL
echo ""
echo "📋 Rollup-boost configuration:"
docker logs "$ROLLUP_BOOST_ID" 2>&1 | grep -i "builder" | head -5 || echo "   (checking logs...)"

echo ""
echo "🔗 Testing connection to external builder..."

# Try to curl the external builder from within the rollup-boost container
if docker exec "$ROLLUP_BOOST_ID" sh -c "command -v curl > /dev/null 2>&1"; then
    echo "   Testing from rollup-boost container..."
    docker exec "$ROLLUP_BOOST_ID" curl -s -f http://host.docker.internal:8561 > /dev/null 2>&1
    if [ $? -eq 0 ]; then
        echo "✅ Can reach external builder from rollup-boost container"
    else
        echo "❌ Cannot reach external builder from rollup-boost container"
        echo "   Make sure your TIPS builder is:"
        echo "   - Running on http://localhost:8561"
        echo "   - Listening on 0.0.0.0 (not just 127.0.0.1)"
        exit 1
    fi
else
    echo "   (curl not available in container, skipping connectivity test)"
fi

echo ""
echo "📊 Rollup-boost recent logs:"
docker logs --tail 20 "$ROLLUP_BOOST_ID" 2>&1

echo ""
echo "✅ Verification complete!"
echo ""
echo "Next steps:"
echo "1. Watch TIPS builder logs for Engine API calls"
echo "2. Send a test transaction to the sequencer"
echo "3. Verify the transaction appears in blocks built by TIPS builder"
