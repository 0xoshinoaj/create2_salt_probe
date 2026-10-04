#!/usr/bin/env bash
# Compute Rescue's CREATE2 address from .env (OWNER, SALT, FACTORY).
set -euo pipefail
cd "$(dirname "$0")/.."

if [[ -f .env ]]; then
  set -a
  # shellcheck disable=SC1091
  source .env
  set +a
fi

OWNER="${OWNER:?set OWNER in .env}"
SALT="${SALT:?set SALT in .env}"
FACTORY="${FACTORY:-0x4e59b44847b379578588920cA78FbF26c0B4956C}"

BYTECODE="$(forge inspect Rescue bytecode)"
ARGS="$(cast abi-encode 'constructor(address)' "$OWNER")"
INIT="${BYTECODE}${ARGS#0x}"

echo "factory:  $FACTORY"
echo "owner:    $OWNER"
echo "salt:     $SALT"
echo "initcode: ${#INIT} hex chars (with 0x)"
echo
cast create2 --deployer "$FACTORY" --salt "$SALT" --init-code "$INIT"
