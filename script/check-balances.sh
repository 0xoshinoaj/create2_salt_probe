#!/usr/bin/env bash
# Free multi-chain check: rotate public RPCs. No paid API.
# Optional: TOKEN=0x...  or  MAJOR_TOKENS=1  (WETH/USDC/USDT on that chain)
set -euo pipefail
cd "$(dirname "$0")/.."

if [[ -f .env ]]; then
  set -a
  # shellcheck disable=SC1091
  source .env
  set +a
fi

ADDR="${ADDR:?set ADDR in .env (from compute-create2.sh output)}"
TOKEN="${TOKEN:-}"
MAJOR_TOKENS="${MAJOR_TOKENS:-0}"

ETH_RPCS=(
  "${ETH_RPC_URL:-}"
  "https://ethereum.publicnode.com"
  "https://1rpc.io/eth"
  "https://eth.drpc.org"
  "https://cloudflare-eth.com"
)
ARB_RPCS=(
  "${ARB_RPC_URL:-}"
  "https://arb1.arbitrum.io/rpc"
  "https://arbitrum-one.publicnode.com"
  "https://1rpc.io/arb"
)
BASE_RPCS=(
  "${BASE_RPC_URL:-}"
  "https://mainnet.base.org"
  "https://base.publicnode.com"
  "https://1rpc.io/base"
)

# native WETH / USDC / USDT (not a full portfolio)
ETH_MAJOR=(
  "WETH:0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2"
  "USDC:0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48"
  "USDT:0xdAC17F958D2ee523a2206206994597C13D831ec7"
)
ARB_MAJOR=(
  "WETH:0x82aF49447D8a07e3bd95BD0d56f35241523fBab1"
  "USDC:0xaf88d065e77c8cC2239327C5EDb3A432268e5831"
  "USDT:0xFd086bC7CD5C481DCC9C85ebE478A1C0b69FCbb9"
)
BASE_MAJOR=(
  "WETH:0x4200000000000000000000000000000000000006"
  "USDC:0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913"
)

rpc_call() {
  local rpc="$1"
  shift
  cast "$@" --rpc-url "$rpc" 2>/dev/null
}

first_working_rpc() {
  local rpc
  for rpc in "$@"; do
    [[ -z "$rpc" ]] && continue
    if rpc_call "$rpc" chain-id >/dev/null; then
      echo "$rpc"
      return 0
    fi
  done
  return 1
}

token_balance() {
  local rpc="$1"
  local token="$2"
  rpc_call "$rpc" call "$token" 'balanceOf(address)(uint256)' "$ADDR" || true
}

check_chain() {
  local name="$1"
  shift
  local -a rpcs=("$@")
  local rpc
  if ! rpc="$(first_working_rpc "${rpcs[@]}")"; then
    echo "[$name] all public RPCs failed"
    return
  fi
  local wei
  wei="$(rpc_call "$rpc" balance "$ADDR")"
  echo "[$name] rpc=$rpc"
  echo "[$name] native wei=$wei ($(cast from-wei "$wei") ETH)"
  if [[ -n "$TOKEN" ]]; then
    echo "[$name] TOKEN $TOKEN = $(token_balance "$rpc" "$TOKEN")"
  fi
}

echo "addr=$ADDR"
echo
check_chain eth "${ETH_RPCS[@]}"
if [[ "$MAJOR_TOKENS" == "1" ]]; then
  rpc="$(first_working_rpc "${ETH_RPCS[@]}")" || rpc=""
  if [[ -n "$rpc" ]]; then
    for pair in "${ETH_MAJOR[@]}"; do
      echo "[eth] ${pair%%:*} = $(token_balance "$rpc" "${pair#*:}")"
    done
  fi
fi
echo
check_chain arb "${ARB_RPCS[@]}"
if [[ "$MAJOR_TOKENS" == "1" ]]; then
  rpc="$(first_working_rpc "${ARB_RPCS[@]}")" || rpc=""
  if [[ -n "$rpc" ]]; then
    for pair in "${ARB_MAJOR[@]}"; do
      echo "[arb] ${pair%%:*} = $(token_balance "$rpc" "${pair#*:}")"
    done
  fi
fi
echo
check_chain base "${BASE_RPCS[@]}"
if [[ "$MAJOR_TOKENS" == "1" ]]; then
  rpc="$(first_working_rpc "${BASE_RPCS[@]}")" || rpc=""
  if [[ -n "$rpc" ]]; then
    for pair in "${BASE_MAJOR[@]}"; do
      echo "[base] ${pair%%:*} = $(token_balance "$rpc" "${pair#*:}")"
    done
  fi
fi
