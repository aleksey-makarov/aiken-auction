#!/usr/bin/env bash
# shellcheck disable=SC1091

. ./functions.sh

# NFT
policy_id=232b62004de2e378406f8a0161825def83e1834b76df240324466766
tokenname_hex=41756374696f6e54657374546f6b656e30
nft="1219730+1 ${policy_id}.${tokenname_hex}"
nft_utxo='859b98ef217fbef871f8a36427d9c1dc9ac7f8152bf0f8dfb6a73d745064ff1f#0'

# Fuel
wallet_address=$(wallets_get_address wallet)
utxo='806b1f0430aae56fedc7c1754a36461a4cbedec96b23ca94da79db39758dbdbb#4'
collateral_utxo='859b98ef217fbef871f8a36427d9c1dc9ac7f8152bf0f8dfb6a73d745064ff1f#1'
utxo_signing_key_file=$(wallets_get_signing_key_file wallet)

# Parameters
bid=3000000

# New data
jq ".fields[5]=
{ constructor:0, fields: [
	{
		constructor:0,
		fields:
		[
			{ bytes: \"$(wallets_get_vkey_hash wallet_nft)\" },
			{ int: $bid }
		]
	}
]}" < data_list.json > data.json

# Redeemer
jq "{ \"constructor\": 0, \"fields\": [ .fields[5].fields[0] ] }" < data.json > redeemer.json

echo "[data] --------------------------------------------------"
cat data.json
echo "[redeemer] ----------------------------------------------"
cat redeemer.json
echo "---------------------------------------------------------"

set -x

tx_unsigned_name=$(mktemp)
tx_signed_name=$(mktemp)

cardano-cli latest transaction build \
    --testnet-magic 2 \
    --out-file "$tx_unsigned_name" \
    --tx-in "$nft_utxo" \
    --tx-in-datum-file data_list.json \
    --tx-in-redeemer-file redeemer.json \
    --tx-in-script-file contract_code.txt \
    --tx-in $utxo \
    --tx-in-collateral $collateral_utxo \
    --change-address "$wallet_address" \
    --tx-out "$(cat contract_address.txt)+${nft}" \
    --invalid-before 12346

# cardano-cli latest transaction sign \
#     --testnet-magic 2 \
#     --tx-body-file "$tx_unsigned_name" \
#     --out-file "$tx_signed_name" \
#     --signing-key-file "$utxo_signing_key_file" \

# cardano-cli latest transaction submit \
#     --testnet-magic 2 \
#     --tx-file "$tx_signed_name"

rm "$tx_unsigned_name"
rm "$tx_signed_name"
