#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

ANVIL_KEY="${ANVIL_KEY:-0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80}"
RPC_URL="${RPC_URL:-http://127.0.0.1:8545}"
# Never reuse Sepolia addresses on a fresh Anvil chain.
unset UERC20_FACTORY LIQUIDITY_LAUNCHER
WEB_DEPLOY="${WEB_DEPLOY:-../launchpad/web/src/lib/deployments/anvil.json}"
NOW="$(date +%s)"
# Max Market is stamped 30d ago; Punks / Virtuoso / Megapot are 1d ago.
# Genesis must be earlier than Max so we can warp forward only.
MAX_CREATED_AT="$((NOW - 2592000))"
PUNKS_CREATED_AT="$((NOW - 86400))"
ANVIL_GENESIS_AT="$((NOW - 2764800))"

if [[ "${ANVIL_ALREADY_RUNNING:-}" != "1" ]]; then
  if command -v lsof >/dev/null 2>&1; then
    if lsof -ti tcp:8545 >/dev/null 2>&1; then
      echo "restarting anvil on :8545"
      kill $(lsof -ti tcp:8545) || true
      sleep 1
    fi
  fi

  anvil --host 127.0.0.1 --port 8545 --chain-id 31337 \
    --timestamp "$ANVIL_GENESIS_AT" \
    --gas-limit 50000000 \
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
  local multiplier=130
  if [[ "$1" == "bidFailed()" || "$1" == "bidMegapot()" || "$1" == "bidGrad()" || "$1" == "bidMaxMarket()" ]]; then
    multiplier=200
  fi
  # Keep automine + a fixed 1 gwei price so 50+ bid txs cannot stall
  # in the mempool after EIP-1559 base fee moves.
  cast rpc evm_setIntervalMining 0 --rpc-url "$RPC_URL" >/dev/null || true
  cast rpc evm_setAutomine true --rpc-url "$RPC_URL" >/dev/null || true
  cast rpc anvil_setNextBlockBaseFeePerGas 0x3b9aca00 --rpc-url "$RPC_URL" >/dev/null || true
  cast rpc evm_mine --rpc-url "$RPC_URL" >/dev/null || true
  PRIVATE_KEY="$ANVIL_KEY" forge script script/SeedFixtures.s.sol:SeedFixturesScript \
    --rpc-url "$RPC_URL" \
    --broadcast \
    --private-key "$ANVIL_KEY" \
    --sig "$1" \
    --gas-estimate-multiplier "$multiplier" \
    --with-gas-price 1000000000 \
    -vv
}

# Tester wallets (100 ETH each) so MetaMask accounts can launch / bid.
# Real transfers (not anvil_setBalance) so MetaMask picks up the incoming tx.
FUND_WALLETS=(
  0xBb6f397d9d8bf128dDa607005397F539B43CD710
  0x530bf56676Af5bdf5B0104Db8CD3d4588AA80735
  0x4489C7836eBE6aBf8a95Ad87877E8123e5F20A25
  0x0BbF921421383edE2837d31c535Fb8452D788aE9
)
for wallet in "${FUND_WALLETS[@]}"; do
  cast send "$wallet" --value 100ether --private-key "$ANVIL_KEY" --rpc-url "$RPC_URL" >/dev/null
  echo "funded $wallet with 100 ETH"
done

WEB_DIR="$(cd ../launchpad/web && pwd)"
if [[ -f "$WEB_DIR/scripts/clear-network-db.mjs" ]]; then
  echo "clearing launchpad DB for Anvil (chain 31337)"
  (cd "$WEB_DIR" && node scripts/clear-network-db.mjs anvil) \
    || echo "warn: could not clear launchpad DB (check SUPABASE_DB_URL in web/.env.local)"
fi

python3 scripts/sign-anvil-x-extras.py

CHAIN_TS="$(cast block latest --rpc-url "$RPC_URL" --field timestamp)"
CHAIN_TS="$((CHAIN_TS))"
if (( CHAIN_TS > MAX_CREATED_AT )); then
  echo "Anvil time is already past the Max Market create stamp (${MAX_CREATED_AT})." >&2
  echo "Start a fresh node (omit ANVIL_ALREADY_RUNNING) so genesis can be 32d ago." >&2
  exit 1
fi

# Max Market at now-30d so it can graduate, then trade across 30 days.
cast rpc evm_setNextBlockTimestamp "$MAX_CREATED_AT" --rpc-url "$RPC_URL" >/dev/null
seed "mintRecruits()"
seed "createMaxMarket()"
cast rpc anvil_mine 1 --rpc-url "$RPC_URL" >/dev/null
seed "seedMaxMarketDistributors()"
seed "bidMaxMarket()"
cast rpc anvil_mine 250 --rpc-url "$RPC_URL" >/dev/null
seed "finalizeMaxMarket()"
seed "deployMaxMarketTrader()"

TRADER="$(tr -d '[:space:]' < deployments/anvil-max-trader.txt)"
if [[ -z "$TRADER" || "$TRADER" == "0x0000000000000000000000000000000000000000" ]]; then
  echo "max market trader address missing" >&2
  exit 1
fi
echo "trading Max Market (Token B curve) via $TRADER"
for d in $(seq 0 28); do
  ts=$((MAX_CREATED_AT + 86400 * (d + 1)))
  cast rpc evm_setNextBlockTimestamp "$ts" --rpc-url "$RPC_URL" >/dev/null
  buy="$(cast call "$TRADER" "dayBuyWei(uint256)(uint256)" "$d" --rpc-url "$RPC_URL" | awk '{print $1}')"
  echo "  day $((d + 1))/30 buy ${buy}"
  cast send "$TRADER" "runDay(uint256)" "$d" \
    --value "$buy" \
    --private-key "$ANVIL_KEY" \
    --rpc-url "$RPC_URL" \
    --gas-price 1000000000 \
    >/dev/null
done

# Day 29 of Max trading already landed at now-1d. Next block is Punks / Virtuoso / Megapot.
seed "createEnded()"
cast rpc anvil_mine 1 --rpc-url "$RPC_URL" >/dev/null
seed "bidGrad()"
seed "bidFailed()"
seed "bidMegapot()"
cast rpc anvil_mine 250 --rpc-url "$RPC_URL" >/dev/null
seed "finalizeEnded()"

# Jump to wall-clock now: last Token B day + live / ending auctions.
cast rpc evm_setNextBlockTimestamp "$(date +%s)" --rpc-url "$RPC_URL" >/dev/null
cast rpc evm_mine --rpc-url "$RPC_URL" >/dev/null
buy="$(cast call "$TRADER" "dayBuyWei(uint256)(uint256)" 29 --rpc-url "$RPC_URL" | awk '{print $1}')"
echo "  day 30/30 buy ${buy}"
cast send "$TRADER" "runDay(uint256)" 29 \
  --value "$buy" \
  --private-key "$ANVIL_KEY" \
  --rpc-url "$RPC_URL" \
  --gas-price 1000000000 \
  >/dev/null
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
        "referrerNft": c["referrerNft"],
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

for src, dst in [
    ("out/ReferrerNFT.sol/ReferrerNFT.json", "../launchpad/web/src/lib/abi/ReferrerNFT.json"),
    ("out/FeeDistributor.sol/FeeDistributor.json", "../launchpad/web/src/lib/abi/FeeDistributor.json"),
    ("out/InviteRegistry.sol/InviteRegistry.json", "../launchpad/web/src/lib/abi/InviteRegistry.json"),
]:
    abi = json.loads(Path(src).read_text())["abi"]
    Path(dst).write_text(json.dumps(abi, indent=2) + "\n")
    print("wrote", dst)
PY

# Tick the block clock after fixtures exist so Ending Soon counts down.
cast rpc evm_setIntervalMining 1 --rpc-url "$RPC_URL" >/dev/null || true

echo
echo "Anvil is running. Import account #0 into your wallet:"
echo "  0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80"
echo "Point the web app at Anvil with NEXT_PUBLIC_LAUNCHPAD_NETWORK=anvil"
echo "Invite codes: failed-invite (Punks) | megapot-invite (Megapot) | grad-invite (Virtuoso) | max-dist-1..5 (Max Market) | ending-invite (Loot Genie)"
