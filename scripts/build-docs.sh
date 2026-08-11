#!/usr/bin/env bash
# Build NatSpec docs (mdBook) from Solidity comments for Vercel / local preview.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

export FOUNDRY_DISABLE_NIGHTLY_WARNING=1
export PATH="${HOME}/.foundry/bin:${HOME}/.cargo/bin:${PATH}"

echo "==> Working dir: ${ROOT}"

install_foundry() {
  if command -v forge >/dev/null 2>&1; then
    echo "==> forge already installed: $(forge --version | head -1)"
    return
  fi

  # foundryup fails on Vercel (/dev/fd/63). Download release binaries directly.
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

  # Archive layout can be flat binaries or a nested folder.
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

install_mdbook() {
  if command -v mdbook >/dev/null 2>&1; then
    echo "==> mdbook already installed: $(mdbook --version)"
    return
  fi

  echo "==> Installing mdBook..."
  MDBOOK_VERSION="v0.4.40"
  ARCH="$(uname -m)"
  OS="$(uname -s)"
  case "${OS}-${ARCH}" in
    Linux-x86_64|Linux-amd64) MDBOOK_ARCH="x86_64-unknown-linux-gnu" ;;
    Linux-aarch64|Linux-arm64) MDBOOK_ARCH="aarch64-unknown-linux-gnu" ;;
    Darwin-arm64) MDBOOK_ARCH="aarch64-apple-darwin" ;;
    Darwin-x86_64) MDBOOK_ARCH="x86_64-apple-darwin" ;;
    *) echo "Unsupported platform: ${OS}-${ARCH}" >&2; exit 1 ;;
  esac

  TMP="$(mktemp -d)"
  curl -fsSL \
    "https://github.com/rust-lang/mdBook/releases/download/${MDBOOK_VERSION}/mdbook-${MDBOOK_VERSION}-${MDBOOK_ARCH}.tar.gz" \
    | tar -xz -C "${TMP}"
  mkdir -p "${HOME}/.cargo/bin"
  mv "${TMP}/mdbook" "${HOME}/.cargo/bin/mdbook"
  chmod +x "${HOME}/.cargo/bin/mdbook"
  rm -rf "${TMP}"
  mdbook --version
}

# lib/* is gitignored, so Vercel clones are empty (or have broken gitlinks).
# Clone what src/ needs for forge doc.
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
    # Vercel cannot clone git@github.com SSH submodule URLs.
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

  # Parent repo may leave a broken gitlink here after "Failed to fetch submodules".
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
      echo "liquidity-launcher libs:" >&2
      ls -la lib/liquidity-launcher/lib >&2 || true
      exit 1
    fi
  done
  echo "==> All required lib files present"
}

install_foundry
install_mdbook
ensure_libs

apply_theme() {
  local out="docs/natspec"
  local theme_dir="docs-theme"

  if [[ ! -d "${out}/src" ]]; then
    echo "Expected ${out}/src from forge doc" >&2
    exit 1
  fi

  echo "==> Applying docs theme..."
  # Additive CSS only — never replace mdBook's theme/ (that breaks layout vars).
  rm -rf "${out}/theme"
  cp "${theme_dir}/custom.css" "${out}/custom.css"

  # forge doc rewrites book.toml every run — restyle + branding here.
  cat > "${out}/book.toml" <<'EOF'
[book]
src = "src"
title = "Prysma Launchpad Documentation"

[output.html]
no-section-label = true
additional-js = ["solidity.min.js"]
additional-css = ["book.css", "custom.css"]
mathjax-support = true
git-repository-url = "https://github.com/prysma-labs/launchpad-contracts"
default-theme = "light"
preferred-dark-theme = "navy"
site-url = "/"

[output.html.fold]
enable = true
EOF

  # Keep forge's table helper CSS if present; otherwise create a stub.
  if [[ ! -f "${out}/book.css" ]]; then
    printf '/* forge book.css placeholder */\n' > "${out}/book.css"
  fi

  echo "==> Building mdBook..."
  (cd "${out}" && mdbook build)
}

echo "==> Generating NatSpec docs..."
FOUNDRY_PROFILE=docs forge doc -o docs/natspec
apply_theme

test -f docs/natspec/book/index.html || {
  echo "Expected docs/natspec/book/index.html missing" >&2
  ls -la docs/natspec || true
  ls -la docs/natspec/book || true
  exit 1
}

echo "==> Docs ready at docs/natspec/book"
