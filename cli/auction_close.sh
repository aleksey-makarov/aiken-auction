#!/usr/bin/env bash
# shellcheck disable=SC1091

. ./functions.sh

# NFT
policy_id=2c8fe90e173051781db0f4f2237cc3f134238736544be17b06af19fe
tokenname_hex=41756374696f6e54657374546f6b656e30
nft="1219730+1 ${policy_id}.${tokenname_hex}"
nft_utxo='db46c45faae95793507bb2d63c6a56c44ef7fc6c3ba783abaf0fa03bda715ab1#0'
# nft_utxo_signing_key_file=$(wallets_get_signing_key_file wallet_nft)

# Contract address
auction_contract=$(aiken blueprint address ..)

# Fuel
wallet_address=$(wallets_get_address wallet)
wallet_vkey_hash=$(wallets_get_vkey_hash wallet)
my_nami_address=addr_test1qzkuktkzekzwg6aepjy6pk7thwe7gwa6pk9exvl7l4ys60luj3pv9vxmhesk92yjdaz5jfrjt9kggvlfw2a7zw49kwvs8n77et
utxo='7469e7216b7fe1fdc3070738a0744446cdc975ab737b1f9df9ccae2430672e6f#0'
utxo_signing_key_file=$(wallets_get_signing_key_file wallet)

# Datum
deadline=12345
min_bid=1000000

# script file
script_file_name="script.ulpc"
aiken blueprint convert .. > $script_file_name

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
    --tx-in "db46c45faae95793507bb2d63c6a56c44ef7fc6c3ba783abaf0fa03bda715ab1#0" \
    --tx-in-datum-file data_list.json \
    --tx-in-redeemer-file "$redeemer_file_name" \
    --tx-in-script-file "$script_file_name" \
    --tx-in-collateral $utxo \
    --change-address "$wallet_address" \
    --out-file "$tx_unsigned_name" \
    --tx-out "$(wallets_get_address wallet)+${nft}" \
    --required-signer-hash $(wallets_get_vkey_hash wallet) \
    --invalid-before 12346

#  --required-signer-hash "$policy_key_hash" \
#  --tx-out "$my_nami_address"+"1202490"+"1 $policyid.$tokenname1" \
#  --tx-in 'c5ba91bf3a84e71fe8d16a3edaacf9466be598174653a4404b5471b8f84fccb3#0' \
#  --tx-out "$roberto_address"+"10000000"+"12 $policyid.$tokenname1" \

# cardano-cli latest transaction sign \
#     --testnet-magic 2 \
#     --tx-body-file "$tx_unsigned_name" \
#     --signing-key-file "$nft_utxo_signing_key_file" \
#     --signing-key-file "$utxo_signing_key_file" \
#     --out-file "$tx_signed_name"

# cardano-cli latest transaction submit \
#     --testnet-magic 2 \
#     --tx-file "$tx_signed_name"

rm "$tx_unsigned_name"
rm "$tx_signed_name"
