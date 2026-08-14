#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

ANVIL_KEY="${ANVIL_KEY:-0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80}"
RPC_URL="${RPC_URL:-http://127.0.0.1:8545}"
# Never reuse Sepolia addresses on a fresh Anvil chain.
unset UERC20_FACTORY LIQUIDITY_LAUNCHER
WEB_DEPLOY="${WEB_DEPLOY:-../launchpad/web/src/lib/deployments/anvil.json}"

if [[ "${ANVIL_ALREADY_RUNNING:-}" != "1" ]]; then
  if command -v lsof >/dev/null 2>&1; then
    if lsof -ti tcp:8545 >/dev/null 2>&1; then
      echo "restarting anvil on :8545"
      kill $(lsof -ti tcp:8545) || true
      sleep 1
    fi
  fi

  anvil --host 127.0.0.1 --port 8545 --chain-id 31337 \
    --block-base-fee-per-gas 1000000000 \
    --gas-price 1000000000 \
    --silent >/tmp/launchpad-anvil.log 2>&1 &
  disown
  echo "anvil pid $!"
fi

for _ in $(seq 1 40); do
  if cast block-number --rpc-url "$RPC_URL" >/dev/null 2>&1; then
    break
  fi
  sleep 0.15
done
cast block-number --rpc-url "$RPC_URL" >/dev/null
# Automine during deploy/seed so forge is not waiting 1s per receipt.
cast rpc evm_setIntervalMining 0 --rpc-url "$RPC_URL" >/dev/null || true
cast rpc evm_setAutomine true --rpc-url "$RPC_URL" >/dev/null || true
cast rpc anvil_setNextBlockBaseFeePerGas 0x3b9aca00 --rpc-url "$RPC_URL" >/dev/null || true

PRIVATE_KEY="$ANVIL_KEY" forge script script/DeployCca.s.sol:DeployCcaScript \
  --rpc-url "$RPC_URL" \
  --broadcast \
  --private-key "$ANVIL_KEY" \
  -vv

seed() {
  PRIVATE_KEY="$ANVIL_KEY" forge script script/SeedFixtures.s.sol:SeedFixturesScript \
    --rpc-url "$RPC_URL" \
    --broadcast \
    --private-key "$ANVIL_KEY" \
    --sig "$1" \
    -vv
}

# Tester wallets (100 ETH each) so MetaMask accounts can launch / bid.
# Real transfers (not anvil_setBalance) so MetaMask picks up the incoming tx.
FUND_WALLETS=(
  0xBb6f397d9d8bf128dDa607005397F539B43CD710
  0x530bf56676Af5bdf5B0104Db8CD3d4588AA80735
  0x4489C7836eBE6aBf8a95Ad87877E8123e5F20A25
)
for wallet in "${FUND_WALLETS[@]}"; do
  cast send "$wallet" --value 100ether --private-key "$ANVIL_KEY" --rpc-url "$RPC_URL" >/dev/null
  echo "funded $wallet with 100 ETH"
done

python3 scripts/sign-anvil-x-extras.py

seed "createEnded()"
cast rpc anvil_mine 1 --rpc-url "$RPC_URL" >/dev/null
seed "bidGrad()"
cast rpc anvil_mine 20 --rpc-url "$RPC_URL" >/dev/null
seed "finalizeEnded()"
seed "createLive()"
cast rpc anvil_mine 1 --rpc-url "$RPC_URL" >/dev/null
seed "bidLive()"
seed "createEnding()"

python3 - <<'PY'
import json
from pathlib import Path

src = json.loads(Path("deployments/anvil-cca.json").read_text())
c = src["cca"]
out = {
    "network": "anvil",
    "chainId": 31337,
    "rpc": "http://127.0.0.1:8545",
    "explorer": "",
    "status": "deployed",
    "deployer": src["deployer"],
    "uniswap": {
        "permit2": c["permit2"],
        "poolManager": c["poolManager"],
        "positionManager": c["positionManager"],
        "swapRouter": c["swapRouter"],
        "universalRouter": "0x0000000000000000000000000000000000000000",
        "stateView": "0x0000000000000000000000000000000000000000",
        "quoter": "0x0000000000000000000000000000000000000000",
        "liquidityLauncher": c["launcher"],
    },
    "cca": {
        "factory": c["factory"],
        "lbpStrategy": c["lbpStrategy"],
        "launcher": c["launcher"],
        "ccaFactory": c["ccaFactory"],
        "positionRecipient": c["positionRecipient"],
        "feeDistributor": c["feeDistributor"],
        "feeHook": c["feeHook"],
        "inviteRegistry": c["inviteRegistry"],
        "inviteValidationHook": c["inviteValidationHook"],
        "uerc20Factory": c["uerc20Factory"],
        "startBlock": c["startBlock"],
    },
}
text = json.dumps(out, indent=2) + "\n"
Path("deployments/anvil.json").write_text(text)
web = Path("../launchpad/web/src/lib/deployments/anvil.json")
web.parent.mkdir(parents=True, exist_ok=True)
web.write_text(text)
print("wrote", web)
PY

# Tick the block clock after fixtures exist so Ending Soon counts down.
cast rpc evm_setIntervalMining 1 --rpc-url "$RPC_URL" >/dev/null || true

echo
echo "Anvil is running. Import account #0 into your wallet:"
echo "  0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80"
echo "Point the web app at Anvil with NEXT_PUBLIC_LAUNCHPAD_NETWORK=anvil"
echo "Invite codes: failed-invite (Punks) | grad-invite (Virtuoso) | live-invite (Prysma) | ending-invite (Loot Genie)"
