#!/usr/bin/env bash
# shellcheck disable=SC1091

. ./functions.sh

# NFT
policy_id=232b62004de2e378406f8a0161825def83e1834b76df240324466766
tokenname_hex=41756374696f6e54657374546f6b656e30
nft="1219730+1 ${policy_id}.${tokenname_hex}"
nft_utxo='859b98ef217fbef871f8a36427d9c1dc9ac7f8152bf0f8dfb6a73d745064ff1f#0'
# nft_utxo_signing_key_file=$(wallets_get_signing_key_file wallet_nft)

# Fuel
wallet_address=$(wallets_get_address wallet)
wallet_vkey_hash=$(wallets_get_vkey_hash wallet)
my_nami_address=addr_test1qzkuktkzekzwg6aepjy6pk7thwe7gwa6pk9exvl7l4ys60luj3pv9vxmhesk92yjdaz5jfrjt9kggvlfw2a7zw49kwvs8n77et
utxo='806b1f0430aae56fedc7c1754a36461a4cbedec96b23ca94da79db39758dbdbb#4'
collateral_utxo='859b98ef217fbef871f8a36427d9c1dc9ac7f8152bf0f8dfb6a73d745064ff1f#1'
utxo_signing_key_file=$(wallets_get_signing_key_file wallet)

# Datum
deadline=12345
min_bid=1000000

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
    --tx-in-datum-file data_list.json \
    --tx-in-redeemer-file "$redeemer_file_name" \
    --tx-in-script-file contract_code.txt \
    --tx-in $utxo \
    --tx-in-collateral $collateral_utxo \
    --change-address "$wallet_address" \
    --tx-out "$(wallets_get_address wallet)+${nft}" \
    --invalid-before 12346

#  --required-signer-hash "$policy_key_hash" \
#  --tx-out "$my_nami_address"+"1202490"+"1 $policyid.$tokenname1" \
#  --tx-in 'c5ba91bf3a84e71fe8d16a3edaacf9466be598174653a4404b5471b8f84fccb3#0' \
#  --tx-out "$roberto_address"+"10000000"+"12 $policyid.$tokenname1" \

cardano-cli latest transaction sign \
    --testnet-magic 2 \
    --tx-body-file "$tx_unsigned_name" \
    --out-file "$tx_signed_name" \
    --signing-key-file "$utxo_signing_key_file" \

#     --signing-key-file "$nft_utxo_signing_key_file" \

cardano-cli latest transaction submit \
    --testnet-magic 2 \
    --tx-file "$tx_signed_name"

rm "$tx_unsigned_name"
rm "$tx_signed_name"
