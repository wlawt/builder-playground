#!/bin/bash
set -e

# Script to build the tips-builder Docker image from the GitHub PR
# This builds the builder from https://github.com/base/tips/pull/111

echo "Building tips-builder Docker image from GitHub PR..."

# Clone the repository and checkout the rblib branch
TEMP_DIR=$(mktemp -d)
trap "rm -rf $TEMP_DIR" EXIT

echo "Cloning repository to $TEMP_DIR..."
git clone --depth 1 --branch rblib https://github.com/base/tips.git "$TEMP_DIR"

# Build the Docker image from the builder directory
echo "Building Docker image..."
cd "$TEMP_DIR"

# Check if Dockerfile exists in crates/builder
if [ ! -f "crates/builder/Dockerfile" ]; then
    echo "Error: Dockerfile not found at crates/builder/Dockerfile"
    echo "The PR might not have a Dockerfile yet. Creating a default one..."

    # Create a basic Dockerfile for the Rust builder
    cat > crates/builder/Dockerfile <<'EOF'
FROM rust:1.83-bookworm as builder

WORKDIR /app

# Copy the workspace files
COPY Cargo.toml Cargo.lock ./
COPY crates ./crates

# Build the builder
WORKDIR /app/crates/builder
RUN cargo build --release

FROM debian:bookworm-slim

# Install runtime dependencies
RUN apt-get update && apt-get install -y \
    ca-certificates \
    libssl3 \
    && rm -rf /var/lib/apt/lists/*

# Copy the binary from builder
COPY --from=builder /app/target/release/tips-builder /usr/local/bin/tips-builder

ENTRYPOINT ["tips-builder"]
EOF
fi

# Build from the crates/builder directory
docker build -f crates/builder/Dockerfile -t tips-builder:latest .

echo "Successfully built tips-builder:latest"
echo ""
echo "You can now run the OpStack recipe with tips-builder:"
echo "  builder-playground cook opstack --external-builder tips-builder"
