#!/usr/bin/env bash
# One entrypoint: increment salt → CREATE2 address → native balance on eth/arb/base → append CSVs.
# Does not deploy or withdraw.
#
# Query failures (429/5xx/timeout) try the next public RPC for that chain.
# empty.csv only when all three chains returned 0. Unreliable rows go to error.csv.
#
# .env: OWNER, FACTORY, START_SALT, END_SALT
# Out:  out/all.csv  out/with-native.csv  out/empty.csv  out/error.csv
set -euo pipefail
cd "$(dirname "$0")/.."

if [[ -f .env ]]; then
  set -a
  # shellcheck disable=SC1091
  source .env
  set +a
fi

OWNER="${OWNER:?set OWNER in .env}"
FACTORY="${FACTORY:-0x4e59b44847b379578588920cA78FbF26c0B4956C}"
START_SALT="${START_SALT:-1}"
END_SALT="${END_SALT:-5}"
SLEEP_SEC="${SLEEP_SEC:-0.2}"

if ! [[ "$START_SALT" =~ ^[0-9]+$ && "$END_SALT" =~ ^[0-9]+$ ]]; then
  echo "START_SALT and END_SALT must be integers" >&2
  exit 1
fi
if (( END_SALT < START_SALT )); then
  echo "END_SALT must be >= START_SALT" >&2
  exit 1
fi

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

# Prints: OK <wei> <rpc>   or   FAIL
query_native() {
  local addr="$1"
  local prefer="$2"
  shift 2
  local rpc wei
  local -a ordered=()
  [[ -n "$prefer" ]] && ordered+=("$prefer")
  for rpc in "$@"; do
    [[ -z "$rpc" || "$rpc" == "$prefer" ]] && continue
    ordered+=("$rpc")
  done
  for rpc in "${ordered[@]}"; do
    if wei="$(cast balance "$addr" --rpc-url "$rpc" 2>/dev/null)"; then
      printf 'OK %s %s\n' "$wei" "$rpc"
      return 0
    fi
  done
  printf 'FAIL\n'
}

ensure_header() {
  local path="$1"
  if [[ ! -f "$path" ]]; then
    echo "salt,address" >"$path"
  fi
}

echo "compiling once…"
forge build
BYTECODE="$(forge inspect Rescue bytecode)"
ARGS="$(cast abi-encode 'constructor(address)' "$OWNER")"
INIT="${BYTECODE}${ARGS#0x}"

ETH_RPC=""
ARB_RPC=""
BASE_RPC=""

mkdir -p out
ALL="out/all.csv"
HIT="out/with-native.csv"
MISS="out/empty.csv"
ERR="out/error.csv"
ensure_header "$ALL"
ensure_header "$HIT"
ensure_header "$MISS"
ensure_header "$ERR"

echo "owner=$OWNER factory=$FACTORY salts=$START_SALT..$END_SALT"
echo "on 429/error: try next RPC; do not treat failed queries as empty"
echo

n="$START_SALT"
while (( n <= END_SALT )); do
  SALT="$(printf '0x%064x' "$n")"
  ADDR="$(cast create2 --deployer "$FACTORY" --salt "$SALT" --init-code "$INIT")"
  LINE="${SALT},${ADDR}"
  echo "$LINE" >>"$ALL"
  echo -n "[$n] $ADDR"

  eth_line="$(query_native "$ADDR" "$ETH_RPC" "${ETH_RPCS[@]}")"
  arb_line="$(query_native "$ADDR" "$ARB_RPC" "${ARB_RPCS[@]}")"
  base_line="$(query_native "$ADDR" "$BASE_RPC" "${BASE_RPCS[@]}")"

  eth_ok=0
  arb_ok=0
  base_ok=0
  eth="FAIL"
  arb="FAIL"
  base="FAIL"

  if [[ "$eth_line" == OK* ]]; then
    eth_ok=1
    # shellcheck disable=SC2086
    set -- $eth_line
    eth="$2"
    ETH_RPC="$3"
  fi
  if [[ "$arb_line" == OK* ]]; then
    arb_ok=1
    set -- $arb_line
    arb="$2"
    ARB_RPC="$3"
  fi
  if [[ "$base_line" == OK* ]]; then
    base_ok=1
    set -- $base_line
    base="$2"
    BASE_RPC="$3"
  fi

  funded=0
  for wei in "$eth" "$arb" "$base"; do
    if [[ "$wei" != "FAIL" && "$wei" != "0" ]]; then
      funded=1
      break
    fi
  done

  all_ok=0
  if (( eth_ok == 1 && arb_ok == 1 && base_ok == 1 )); then
    all_ok=1
  fi

  if (( funded == 1 )); then
    echo "$LINE" >>"$HIT"
    echo "  native eth=$eth arb=$arb base=$base  -> with-native.csv"
  elif (( all_ok == 1 )); then
    echo "$LINE" >>"$MISS"
    echo "  empty  -> empty.csv"
  else
    echo "$LINE" >>"$ERR"
    echo "  unreliable eth=$eth arb=$arb base=$base  -> error.csv (not empty)"
  fi

  n=$((n + 1))
  sleep "$SLEEP_SEC"
done
