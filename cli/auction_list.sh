#!/usr/bin/env bash
# shellcheck disable=SC1091

. ./functions.sh

# NFT
policy_id=232b62004de2e378406f8a0161825def83e1834b76df240324466766
tokenname_hex=41756374696f6e54657374546f6b656e30
nft="1219730+1 ${policy_id}.${tokenname_hex}"
nft_utxo='a866e1f106d2786e4c1f953ae8b187ba0d2c4493fbc258af0355993d7b1d3615#0'
nft_utxo_signing_key_file=$(wallets_get_signing_key_file wallet_nft)

# Fuel
wallet_address=$(wallets_get_address wallet)
wallet_vkey_hash=$(wallets_get_vkey_hash wallet)
utxo='859b98ef217fbef871f8a36427d9c1dc9ac7f8152bf0f8dfb6a73d745064ff1f#1'
utxo_signing_key_file=$(wallets_get_signing_key_file wallet)

now=$(date '+%s')
now_2h=$((now + S_IN_HOUR * 2))

# Datum
deadline=$(preview_unix_to_slot "$now_2h")
min_bid=10000000

data_file_name=data.json
cat << EOF > "$data_file_name"
{
    "constructor": 0,
    "fields": [
        {
            "bytes": "$wallet_vkey_hash"
        },
        {
            "int": $deadline
        },
        {
            "int": $min_bid
        },
        {
            "bytes": "$policy_id"
        },
        {
            "bytes": "$tokenname_hex"
        },
        {
            "constructor": 1,
            "fields": []
        }
    ]
}
EOF

set -x

tx_unsigned_name=$(mktemp)
tx_signed_name=$(mktemp)

cardano-cli latest transaction build \
    --testnet-magic 2 \
    --out-file "$tx_unsigned_name" \
    --tx-in $nft_utxo \
    --tx-in $utxo \
    --change-address "$wallet_address" \
    --tx-out "$(cat contract_address.txt)+${nft}" \
    --tx-out-datum-hash-file "$data_file_name"

cardano-cli latest transaction sign \
    --testnet-magic 2 \
    --tx-body-file "$tx_unsigned_name" \
    --out-file "$tx_signed_name" \
    --signing-key-file "$nft_utxo_signing_key_file" \
    --signing-key-file "$utxo_signing_key_file" \

cardano-cli latest transaction submit \
    --testnet-magic 2 \
    --tx-file "$tx_signed_name"

rm "$tx_unsigned_name"
rm "$tx_signed_name"
