#!/usr/bin/env bash
# Generate NatSpec (forge doc) and build / serve HonKit.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

export FOUNDRY_DISABLE_NIGHTLY_WARNING=1
export PATH="${HOME}/.foundry/bin:${HOME}/.cargo/bin:${PATH}"

MODE="${1:-build}"

install_foundry() {
  if command -v forge >/dev/null 2>&1; then
    echo "==> forge already installed: $(forge --version | head -1)"
    return
  fi

  FOUNDRY_VERSION="${FOUNDRY_VERSION:-v1.7.1}"
  ARCH="$(uname -m)"
  OS="$(uname -s)"
  case "${OS}-${ARCH}" in
    Linux-x86_64|Linux-amd64) FOUNDRY_TARGET="linux_amd64" ;;
    Linux-aarch64|Linux-arm64) FOUNDRY_TARGET="linux_arm64" ;;
    Darwin-arm64) FOUNDRY_TARGET="darwin_arm64" ;;
    Darwin-x86_64) FOUNDRY_TARGET="darwin_amd64" ;;
    *) echo "Unsupported platform for Foundry: ${OS}-${ARCH}" >&2; exit 1 ;;
  esac

  echo "==> Installing Foundry ${FOUNDRY_VERSION} (${FOUNDRY_TARGET})..."
  mkdir -p "${HOME}/.foundry/bin"
  TMP="$(mktemp -d)"
  curl -fsSL \
    "https://github.com/foundry-rs/foundry/releases/download/${FOUNDRY_VERSION}/foundry_${FOUNDRY_VERSION}_${FOUNDRY_TARGET}.tar.gz" \
    | tar -xz -C "${TMP}"

  find "${TMP}" -type f \( -name forge -o -name cast -o -name anvil -o -name chisel \) -exec mv {} "${HOME}/.foundry/bin/" \;
  chmod +x "${HOME}/.foundry/bin/"*
  rm -rf "${TMP}"

  export PATH="${HOME}/.foundry/bin:${PATH}"
  command -v forge >/dev/null 2>&1 || {
    echo "forge missing after binary install" >&2
    ls -la "${HOME}/.foundry/bin" >&2 || true
    exit 1
  }
  forge --version
}

# lib/* is gitignored, so Vercel clones are empty (or have broken gitlinks).
ensure_libs() {
  mkdir -p lib

  clone_repo() {
    local dest="$1"
    local url="$2"
    local marker="$3"
    if [[ -f "${marker}" ]]; then
      echo "==> lib ok: ${dest}"
      return
    fi
    echo "==> Cloning ${url} -> ${dest}"
    rm -rf "${dest}"
    git clone --depth 1 "${url}" "${dest}"
  }

  init_submodules() {
    local repo="$1"
    shift
    if [[ ! -f "${repo}/.gitmodules" ]]; then
      return
    fi
    if grep -q 'git@github.com:' "${repo}/.gitmodules"; then
      echo "==> Rewriting SSH submodule URLs to HTTPS in ${repo}"
      sed -i.bak 's#git@github.com:#https://github.com/#g' "${repo}/.gitmodules"
      rm -f "${repo}/.gitmodules.bak"
    fi

    local available=()
    local path
    for path in "$@"; do
      if grep -Eq "^[[:space:]]*path = ${path}\$" "${repo}/.gitmodules"; then
        available+=("${path}")
      else
        echo "==> skip ${repo}/${path} (not in .gitmodules)"
      fi
    done
    if [[ ${#available[@]} -eq 0 ]]; then
      return
    fi

    echo "==> Submodules in ${repo}: ${available[*]}"
    git -C "${repo}" submodule sync --recursive
    git -C "${repo}" submodule update --init --depth 1 "${available[@]}"
    for path in "${available[@]}"; do
      if [[ -f "${repo}/${path}/.gitmodules" ]]; then
        if grep -q 'git@github.com:' "${repo}/${path}/.gitmodules"; then
          sed -i.bak 's#git@github.com:#https://github.com/#g' "${repo}/${path}/.gitmodules"
          rm -f "${repo}/${path}/.gitmodules.bak"
          git -C "${repo}/${path}" submodule sync --recursive
        fi
        git -C "${repo}/${path}" submodule update --init --recursive --depth 1
      fi
    done
  }

  clone_repo lib/forge-std \
    https://github.com/foundry-rs/forge-std \
    lib/forge-std/src/Test.sol

  clone_repo lib/continuous-clearing-auction \
    https://github.com/Uniswap/continuous-clearing-auction \
    lib/continuous-clearing-auction/src/interfaces/IValidationHook.sol
  init_submodules lib/continuous-clearing-auction \
    lib/forge-std \
    lib/openzeppelin-contracts \
    lib/solady \
    lib/v4-periphery \
    lib/blocknumberish

  clone_repo lib/uniswap-hooks \
    https://github.com/openzeppelin/uniswap-hooks \
    lib/uniswap-hooks/src/utils/CurrencySettler.sol
  init_submodules lib/uniswap-hooks \
    lib/v4-core \
    lib/v4-periphery \
    lib/openzeppelin-contracts \
    lib/forge-std

  clone_repo lib/hookmate \
    https://github.com/akshatmittal/hookmate \
    lib/hookmate/src/interfaces/router/IUniswapV4Router04.sol

  clone_repo lib/liquidity-launcher \
    https://github.com/Uniswap/liquidity-launcher \
    lib/liquidity-launcher/src/LiquidityLauncher.sol
  init_submodules lib/liquidity-launcher \
    lib/forge-std \
    lib/v4-core \
    lib/v4-periphery \
    lib/openzeppelin-contracts \
    lib/solady \
    lib/blocknumberish \
    lib/uerc20-factory \
    lib/permit2

  local uerc20="lib/liquidity-launcher/lib/uerc20-factory"
  local uerc20_pin="a747318fcce114f56a3a21b8bcec83663a61208b"
  if [[ -d "${uerc20}/.git" ]] || [[ -f "${uerc20}/.git" ]]; then
    echo "==> Pinning uerc20-factory to ${uerc20_pin} (extraData)"
    git -C "${uerc20}" fetch --depth 1 origin "${uerc20_pin}" 2>/dev/null || \
      git -C "${uerc20}" fetch --depth 1 origin main
    git -C "${uerc20}" checkout -q "${uerc20_pin}" || \
      git -C "${uerc20}" checkout -q origin/main
  fi

  local required=(
    lib/liquidity-launcher/lib/v4-core/src/types/PoolId.sol
    lib/liquidity-launcher/lib/v4-core/src/types/Currency.sol
    lib/liquidity-launcher/lib/v4-core/src/libraries/TickMath.sol
    lib/liquidity-launcher/lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol
    lib/continuous-clearing-auction/src/interfaces/IValidationHook.sol
    lib/uniswap-hooks/src/utils/CurrencySettler.sol
  )
  local f
  for f in "${required[@]}"; do
    if [[ ! -f "${f}" ]]; then
      echo "Missing required dependency file: ${f}" >&2
      ls -la lib/liquidity-launcher/lib >&2 || true
      exit 1
    fi
  done
  echo "==> All required lib files present"
}

generate_natspec() {
  echo "==> Generating NatSpec docs..."
  rm -rf .natspec
  FOUNDRY_PROFILE=docs forge doc -o .natspec
  python3 scripts/import_natspec.py
}

install_foundry
ensure_libs
generate_natspec

if [[ "${MODE}" == "serve" ]]; then
  echo "==> Serving HonKit at http://localhost:4000"
  exec pnpm exec honkit serve
fi

echo "==> Building HonKit..."
pnpm exec honkit build
test -f _book/index.html || {
  echo "Expected _book/index.html missing" >&2
  exit 1
}
echo "==> Docs ready at _book/"
