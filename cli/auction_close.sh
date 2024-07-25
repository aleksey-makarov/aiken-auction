#!/usr/bin/env bash
# shellcheck disable=SC1091

. ./functions.sh

ada_output="$(< transaction_nft.txt)#1"
ada_wallet=wallet

seller_wallet=wallet_nft

collateral_utxo='fbcee297003514d56f2dda78484e393b9b8b0ee313f10b5d126e7fe216c13847#0'

# --------------------------------------------------------------------

# NFT
policy_id=$(< nft_policy_id.txt)
tokenname_hex=$(< nft_name_hex.txt)
nft="1 ${policy_id}.${tokenname_hex}"
nft_utxo="$(< transaction_nft.txt)#0"
# nft_utxo="496d9b41fc24ff74eeedbbd5843980ceef89b203a0c6ff476c58be343bbbc6f9#0"

deadline=$(jq ".fields[1].int" data.json)
deadline_unix=$((deadline / 1000))
echo "deadline date: $(date --date="@$deadline_unix") ($deadline_unix)"
deadline_slot=$(preview_unix_to_slot $deadline_unix)

cardano-cli latest query protocol-parameters \
    --testnet-magic 2 \
    --out-file protocol-parameters.json \
    || exit 1

cli_args=()
highest_bid_constructor=$(jq ".fields[5].constructor" data.json)
if [ "$highest_bid_constructor" == 1 ] ; then
    echo "No bids so far"
    echo "Just return the NFT to the seller"

    min_utxo_x=$(cardano-cli latest transaction calculate-min-required-utxo \
        --protocol-params-file protocol-parameters.json \
        --tx-out "$(wallets_get_address $seller_wallet)+${nft}") \
        || exit 1

    min_utxo="${min_utxo_x##Lovelace }"

    cli_args+=( --tx-out )
    cli_args+=( "$(wallets_get_address $seller_wallet)+$min_utxo+$nft" )

else
    highest_bid=$(jq ".fields[5].fields[0].fields[1].int" data.json)
    echo "Highest bid: $highest_bid"
    echo "Send the NFT to the bidder, send the bid to the seller"

    min_utxo_x=$(cardano-cli latest transaction calculate-min-required-utxo \
        --protocol-params-file protocol-parameters.json \
        --tx-out "$(wallets_get_address wallet)+${nft}") \
        || exit 1

    min_utxo="${min_utxo_x##Lovelace }"

    cli_args+=( --tx-out )
    cli_args+=( "$(wallets_get_address wallet)+$min_utxo+${nft}" )
    cli_args+=( --tx-out )
    cli_args+=( "$(wallets_get_address $seller_wallet)+$highest_bid" )
fi

echo "${cli_args[@]}"

# Redeemer

cat << EOF > redeemer.json
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
    --tx-in-script-file contract_code.txt \
    --tx-in-inline-datum-present \
    --tx-in-redeemer-file redeemer.json \
    --tx-in "$ada_output" \
    --tx-in-collateral $collateral_utxo \
    --change-address "$(wallets_get_address $ada_wallet)" \
    "${cli_args[@]}" \
    --invalid-before $((deadline_slot + 1)) \
    || exit 1

cardano-cli latest transaction sign \
    --testnet-magic 2 \
    --tx-body-file "$tx_unsigned_name" \
    --out-file "$tx_signed_name" \
    --signing-key-file "$(wallets_get_signing_key_file $ada_wallet)" \
    || exit 1

cardano-cli latest transaction submit \
    --testnet-magic 2 \
    --tx-file "$tx_signed_name" \
    || exit 1

cardano-cli latest transaction txid --tx-body-file "$tx_unsigned_name" > transaction_nft.txt

rm "$tx_unsigned_name"
rm "$tx_signed_name"
