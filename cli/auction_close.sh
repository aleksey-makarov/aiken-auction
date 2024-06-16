#!/usr/bin/env bash
# shellcheck disable=SC1091

. ./functions.sh

# NFT
policy_id=232b62004de2e378406f8a0161825def83e1834b76df240324466766
tokenname_hex=41756374696f6e54657374546f6b656e30
nft="1219730+1 ${policy_id}.${tokenname_hex}"
nft_utxo='da9be8f094332fd4076381b59683a1a47bfa9423930f8b3c4dd7061fb2ec66b1#0'

# Fuel
wallet_address=$(wallets_get_address wallet)
utxo='9d1380c546f66f0d01bc279f046abd1e45de3eda581770a76177a71b70a5bfb0#1'
collateral_utxo='fbcee297003514d56f2dda78484e393b9b8b0ee313f10b5d126e7fe216c13847#0'
utxo_signing_key_file=$(wallets_get_signing_key_file wallet)

# Redeemer
redeemer_file_name=redeemer.json
cat << EOF > "$redeemer_file_name"
{
    "constructor": 1,
    "fields": []
}
EOF

set -x

tx_unsigned_name=$(mktemp)
tx_signed_name=$(mktemp)

cardano-cli latest transaction build \
    --testnet-magic 2 \
    --out-file "$tx_unsigned_name" \
    --tx-in "$nft_utxo" \
    --tx-in-datum-file data_list2.json \
    --tx-in-redeemer-file "$redeemer_file_name" \
    --tx-in-script-file contract_code.txt \
    --tx-in $utxo \
    --tx-in-collateral $collateral_utxo \
    --change-address "$wallet_address" \
    --tx-out "$(wallets_get_address wallet)+${nft}" \
    --invalid-before 12346

cardano-cli latest transaction sign \
    --testnet-magic 2 \
    --tx-body-file "$tx_unsigned_name" \
    --out-file "$tx_signed_name" \
    --signing-key-file "$utxo_signing_key_file" \

cardano-cli latest transaction submit \
    --testnet-magic 2 \
    --tx-file "$tx_signed_name"

rm "$tx_unsigned_name"
rm "$tx_signed_name"
