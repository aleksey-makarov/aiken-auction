#!/usr/bin/env bash
# shellcheck disable=SC1091

. ./functions.sh

# NFT
policy_id=2c8fe90e173051781db0f4f2237cc3f134238736544be17b06af19fe
tokenname_hex=41756374696f6e54657374546f6b656e30
nft="1219730+1 ${policy_id}.${tokenname_hex}"
nft_utxo='d7ac59bb34c69fb8593a9679f1dda64d76b74a2bddc94a58692ccfd21036f342#0'
nft_utxo_signing_key_file=$(wallets_get_signing_key_file wallet_nft)

# Contract address
auction_contract=$(aiken blueprint address ..)

# Fuel
wallet_address=$(wallets_get_address wallet)
wallet_vkey_hash=$(wallets_get_vkey_hash wallet)
my_nami_address=addr_test1qzkuktkzekzwg6aepjy6pk7thwe7gwa6pk9exvl7l4ys60luj3pv9vxmhesk92yjdaz5jfrjt9kggvlfw2a7zw49kwvs8n77et
utxo='34379f064be45461e7ad1735230d6ad3d9b326d9f7b95eb730f9a614957a10d1#0'
utxo_signing_key_file=$(wallets_get_signing_key_file wallet)

# Datum
deadline=12345
min_bid=1000000

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
    --tx-in $nft_utxo \
    --tx-in $utxo \
    --change-address "$wallet_address" \
    --out-file "$tx_unsigned_name" \
    --tx-out "${auction_contract}+${nft}" \
    --tx-out-datum-hash-file "$data_file_name"

#  --required-signer-hash "$policy_key_hash" \
#  --tx-out "$my_nami_address"+"1202490"+"1 $policyid.$tokenname1" \
#  --tx-in 'c5ba91bf3a84e71fe8d16a3edaacf9466be598174653a4404b5471b8f84fccb3#0' \
#  --tx-out "$roberto_address"+"10000000"+"12 $policyid.$tokenname1" \

cardano-cli latest transaction sign \
    --testnet-magic 2 \
    --tx-body-file "$tx_unsigned_name" \
    --signing-key-file "$nft_utxo_signing_key_file" \
    --signing-key-file "$utxo_signing_key_file" \
    --out-file "$tx_signed_name"

cardano-cli latest transaction submit \
    --testnet-magic 2 \
    --tx-file "$tx_signed_name"

rm "$tx_unsigned_name"
rm "$tx_signed_name"
