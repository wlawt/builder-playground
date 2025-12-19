# Op Stack with Tips Builder

This example shows how to deploy an Op Stack with the tips-builder, which includes UserOp (User Operation) support via Kafka messaging.

The tips-builder is based on https://github.com/base/tips/pull/111 and includes:
- UserOp handling and validation
- Kafka-based messaging for user operations
- Bundle creation for efficient transaction processing

## Prerequisites

Before running the OpStack with tips-builder, you need to build the Docker image:

```bash
$ ./scripts/build-tips-builder.sh
```

This script will:
1. Clone the tips repository from the `rblib` branch
2. Build the Docker image as `tips-builder:latest`
3. Make it available for the playground to use

## Running with Tips Builder

Deploy the Op Stack with tips-builder as the external builder:

```bash
$ builder-playground cook opstack --external-builder tips-builder
```

This will deploy an Op Stack chain with:

- A complete L1 setup (CL/EL)
- A complete L2 sequencer (op-geth/op-node/op-batcher)
- Kafka for UserOp messaging
- Tips-builder as the external block builder with UserOp support

## With Flashblocks

You can also enable Flashblocks support:

```bash
$ builder-playground cook opstack --external-builder tips-builder --flashblocks
```

This adds:
- Flashblocks-RPC for pre-confirmations
- Rollup-boost with Flashblocks enabled
- Tips-builder configured to deliver flashblocks

## Architecture

When using tips-builder, the following services are deployed:

```
┌─────────────┐
│   Kafka     │  UserOp messages
└──────┬──────┘
       │
       ▼
┌─────────────┐
│tips-builder │  Processes UserOps and builds blocks
└──────┬──────┘
       │
       ▼
┌─────────────┐
│rollup-boost │  Routes to tips-builder
└──────┬──────┘
       │
       ▼
┌─────────────┐
│   op-node   │  Sequencer
└─────────────┘
```

## Sending UserOps

The tips-builder listens for UserOps on Kafka. To send a UserOp:

1. Connect to Kafka (exposed on the default port)
2. Send UserOp messages to the `tips-user-operation` topic
3. The builder will validate and bundle them into blocks

## Notes

- The tips-builder requires Kafka to be running for UserOp support
- The builder automatically creates the required Kafka topics
- UserOps are validated before being included in bundles
- The existing external builder functionality (URLs like `http://host.docker.internal:4444`) continues to work
