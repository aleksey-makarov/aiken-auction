#!/usr/bin/env bash
# shellcheck disable=SC1091

. functions.sh

for i in $WALLETS ; do

echo
echo [$i]
check_utxo "$i"

done
