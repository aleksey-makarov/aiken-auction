#!/usr/bin/env bash
# shellcheck disable=SC1091

. ./functions.sh

# from this
utxo='c6a66e9f7c447ae85a07fb837f90e757ab92beec1333c71efa983ecad1c01972#0'
utxo_signing_key_file=$(wallets_get_signing_key_file wallet2)

# to this
wallet_address=$(wallets_get_address wallet)

tx_unsigned_name=$(mktemp)
tx_signed_name=$(mktemp)

cardano-cli latest transaction build \
    --testnet-magic 2 \
    --tx-in $utxo \
    --tx-in '6a90b2626f80691ba212811ab031030b34cefb918d5e4a0d800f0e43da8797cd#1' \
    --change-address "$wallet_address" \
    --out-file "$tx_unsigned_name" \

#  --tx-out "$my_nami_address"+"1193870"+"1 $policy_id.$tokenname_hex" \
#  --tx-out "$my_nami_address"+"1202490"+"1 $policyid.$tokenname1" \
#  --tx-in 'c5ba91bf3a84e71fe8d16a3edaacf9466be598174653a4404b5471b8f84fccb3#0' \
#  --tx-out "$roberto_address"+"10000000"+"12 $policyid.$tokenname1" \

cardano-cli latest transaction sign \
    --testnet-magic 2 \
    --tx-body-file "$tx_unsigned_name" \
    --signing-key-file "$utxo_signing_key_file" \
    --signing-key-file $(wallets_get_signing_key_file wallet) \
    --out-file "$tx_signed_name"

cardano-cli latest transaction submit \
    --testnet-magic 2 \
    --tx-file "$tx_signed_name"

rm "$tx_unsigned_name"
rm "$tx_signed_name"
