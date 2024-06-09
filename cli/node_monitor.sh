#!/usr/bin/env bash
# shellcheck disable=SC1091

. ./functions.sh

now_unix=$(date '+%s')
now=$(date --date="@$now_unix")

echo "$now ($now_unix)"

echo
echo -n "Preview: "
# du -sh "/var/lib/cardano-node/db-preview"
cardano-cli latest query tip --testnet-magic 2
