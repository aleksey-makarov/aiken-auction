#!/usr/bin/env bash
# shellcheck disable=SC1091

# FIXME: use inline data

. ./functions.sh

ada_output="$(< transaction_nft.txt)#1"
# ada_output="69fba33494f086e0671e098a62d46c7d4d88a11020075ae0a02c3c7e9d547724#1"
ada_wallet=wallet

# seller_wallet=wallet_nft

collateral_utxo='fbcee297003514d56f2dda78484e393b9b8b0ee313f10b5d126e7fe216c13847#0'

# -----------------------------------------------------------------

# NFT
policy_id=$(< nft_policy_id.txt)
tokenname_hex=$(< nft_name_hex.txt)
nft="1 ${policy_id}.${tokenname_hex}"
nft_utxo="$(< transaction_nft.txt)#0"
# nft_utxo="496d9b41fc24ff74eeedbbd5843980ceef89b203a0c6ff476c58be343bbbc6f9#0"

# Parameters
deadline=$(jq ".fields[1].int" data.json)
deadline_unix=$((deadline / 1000))
deadline_slot=$(preview_unix_to_slot $deadline_unix)

highest_bid_constructor=$(jq ".fields[5].constructor" data.json)
if [ "$highest_bid_constructor" == 1 ] ; then
    min_bid=$(jq ".fields[2].int" data.json)
    echo "No bids so far, minimal bid: $min_bid"
    refund_command_line_argument=""
else
    min_bid=$(jq ".fields[5].fields[0].fields[1].int" data.json)
    echo "Highest bid: $min_bid"
    refund_command_line_argument="--tx-out=$(wallets_get_address wallet)+$min_bid"
fi

bid=$((min_bid + 1000000))
echo "Bid: $bid"

# New data
jq ".fields[5]=
{ constructor:0, fields: [
	{
		constructor:0,
		fields:
		[
			{ bytes: \"$(wallets_get_vkey_hash wallet)\" },
			{ int: $bid }
		]
	}
]}" < data.json > data_new.json

# Redeemer
jq "{ \"constructor\": 0, \"fields\": [ .fields[5].fields[0] ] }" < data_new.json > redeemer.json

# echo "[data] --------------------------------------------------"
# cat data.json
# cardano-cli latest transaction hash-script-data --script-data-file data.json
# echo "[data_new] --------------------------------------------------"
# cat data_new.json
# cardano-cli latest transaction hash-script-data --script-data-file data_new.json
# echo "[redeemer] ----------------------------------------------"
# cat redeemer.json
# echo "---------------------------------------------------------"

set -x

tx_unsigned_name=$(mktemp)
tx_signed_name=$(mktemp)

cardano-cli transaction build \
    --babbage-era \
    --testnet-magic 2 \
    --out-file "$tx_unsigned_name" \
    --tx-in "$nft_utxo" \
    --tx-in-script-file contract_code.txt \
    --tx-in-datum-file data.json \
    --tx-in-redeemer-file redeemer.json \
    --tx-in "$ada_output" \
    --tx-in-collateral $collateral_utxo \
    --change-address "$(wallets_get_address $ada_wallet)" \
    --tx-out "$(cat contract_address.txt)+$bid+${nft}" \
    --tx-out-datum-embed-file data_new.json \
    "$refund_command_line_argument" \
    --invalid-hereafter $((deadline_slot - 1)) \
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
rm data.json
mv data_new.json data.json

rm "$tx_unsigned_name"
rm "$tx_signed_name"
