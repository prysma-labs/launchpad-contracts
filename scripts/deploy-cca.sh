#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
set -a
source .env
set +a
: "${PRIVATE_KEY:?set PRIVATE_KEY}"
: "${RPC_URL:=${BASE_SEPOLIA_RPC_URL:-https://sepolia.base.org}}"

forge script script/DeployCca.s.sol:DeployCcaScript \
  --rpc-url "$RPC_URL" \
  --broadcast \
  --private-key "$PRIVATE_KEY" \
  -vvv
