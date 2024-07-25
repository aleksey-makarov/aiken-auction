#!/usr/bin/env bash
# shellcheck disable=SC1091

. ./functions.sh

ada_output='e6afa2630130e2830f980ac2e331655bdba08ddb7e15d2a0c8d6b04fd442006a#1'
ada_wallet=wallet

seller_wallet=wallet_nft

delta=$((10 * S_IN_MIN))
# delta=$((10))

# ----------------------------------------------------------

# NFT
policy_id=$(< nft_policy_id.txt)
tokenname_hex=$(< nft_name_hex.txt)
nft="1 ${policy_id}.${tokenname_hex}"

# Datum
now=$(date '+%s')
deadline=$((now + delta))

echo "deadline date: $(date --date="@$deadline")"

min_bid=10000000

cat << EOF > data.json
{
    "constructor": 0,
    "fields": [
        {
            "bytes": "$(wallets_get_vkey_hash $seller_wallet)"
        },
        {
            "int": $((deadline * 1000))
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

tx_unsigned_name=$(mktemp)
tx_signed_name=$(mktemp)

cardano-cli latest query protocol-parameters \
    --testnet-magic 2 \
    --out-file protocol-parameters.json

min_utxo_x=$(cardano-cli latest transaction calculate-min-required-utxo \
    --protocol-params-file protocol-parameters.json \
    --tx-out "$(< contract_address.txt)+${nft}" \
    --tx-out-inline-datum-file data.json)

min_utxo="${min_utxo_x##Lovelace }"

set -x

cardano-cli latest transaction build \
    --testnet-magic 2 \
    --out-file "$tx_unsigned_name" \
    --mint "$nft" \
    --mint-script-file nft_script.json \
    --tx-in $ada_output \
    --change-address "$(wallets_get_address $ada_wallet)" \
    --tx-out "$(< contract_address.txt)+${min_utxo}+${nft}" \
    --tx-out-inline-datum-file data.json \
    --required-signer-hash "$(wallets_get_vkey_hash $seller_wallet)" \
    --metadata-json-file nft_methadata.json \
    || exit 1

cardano-cli latest transaction sign \
    --testnet-magic 2 \
    --tx-body-file "$tx_unsigned_name" \
    --out-file "$tx_signed_name" \
    --signing-key-file "$(wallets_get_signing_key_file $seller_wallet)" \
    --signing-key-file "$(wallets_get_signing_key_file $ada_wallet)" \
    || exit 1

cardano-cli latest transaction submit \
    --testnet-magic 2 \
    --tx-file "$tx_signed_name" \
    || exit 1

cardano-cli latest transaction txid --tx-body-file "$tx_unsigned_name" > transaction_nft.txt

echo "transaction: "
cat transaction_nft.txt

rm "$tx_unsigned_name"
rm "$tx_signed_name"
