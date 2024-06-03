#!/usr/bin/env bash
# shellcheck disable=SC1091

. functions.sh

echo
echo wallet:
check_utxo wallet

echo
echo "wallet2:"
check_utxo wallet2

echo
echo "walletB (attic):"
check_utxo walletB

