#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
set -a
if [[ -f .env.local ]]; then
  # shellcheck disable=SC1091
  source .env.local
fi
set +a
: "${PRIVATE_KEY:?set PRIVATE_KEY in .env.local}"
: "${RPC_URL:=${BASE_SEPOLIA_RPC_URL:-https://sepolia.base.org}}"

forge script script/DeployCca.s.sol:DeployCcaScript \
  --rpc-url "$RPC_URL" \
  --broadcast \
  --private-key "$PRIVATE_KEY" \
  -vvv
