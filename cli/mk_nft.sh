#!/usr/bin/env bash
# shellcheck disable=SC1091

. ./functions.sh

tx_unsigned_name=$(mktemp)
tx_signed_name=$(mktemp)
 
#wrap terminal
# echo -ne "\x1b[?7h"

#unwrap terminal
# echo -ne "\x1b[?7l"

images[0]="QmRa55E1f7wecRJYFNoUkFReopuTyQyRcdAJxodb4UGWqM"
images[1]="QmPwTdg9xGSEroAggB5sW6VLfyAVzmGYVxWnrh5FccTfYF"
images[2]="QmYWkzCfy3sZT9ExHFzzBXncfLw434tYVfhuzxvNFR7k1G"
images[3]="QmSJujeMVea3bw39jFmzqUrvWfPPhhFtYvcoM9Fd26ecXn"
images[4]="QmYJwCVQAMegQC6mWJqNrA3DmRtKC48moB5NbQgwFCbdwV"
images[5]="QmYusLQ1AxcWVmNaXxeHvciCvn4SuJfAWwQRU7jASWWoaf"
images[6]="Qmd2hMufefhxLoqzphnPUEd4GJqrYBQ7VPYzLzZfJuEvH5"
images[7]="QmSma1PXmTQqEuwMoW16mYY6BJ1w9ErNTqExPxKfepTnhZ"
images[8]="QmQjmAPQhPqVdyMWrmVJcfJoJocpz8x86jAMvHCcfDPbbE"
images[9]="QmQpjVG4Fgo6ft5L7XTWupGpj1aijW8e8BZ8av4YqZtdYS"

for image_index in "${!images[@]}" ; do
	echo "$image_index: ${images[image_index]}"
done

image_index=0

wallet_address=$(wallets_get_address wallet)
my_nami_address=addr_test1qzkuktkzekzwg6aepjy6pk7thwe7gwa6pk9exvl7l4ys60luj3pv9vxmhesk92yjdaz5jfrjt9kggvlfw2a7zw49kwvs8n77et

utxo='7469e7216b7fe1fdc3070738a0744446cdc975ab737b1f9df9ccae2430672e6f#0'
utxo_signing_key_file=$(wallets_get_signing_key_file wallet)

policy_script_name="nft_policy.script"
policy_wallet=wallet_nft
policy_key_hash=$(wallets_get_vkey_hash "$policy_wallet")
policy_signing_key_file=$(wallets_get_signing_key_file "$policy_wallet")

cat << EOF > "$policy_script_name"
{
	"type" : "all",
	"scripts" : [
		{
			"type" : "sig",
			"keyHash" : "$policy_key_hash"
		}
	]
}
EOF

policy_id=$(cardano-cli transaction policyid --script-file "$policy_script_name")
echo "Policy ID: $policy_id"

methadata_file_name="nft_methadata.json"
tokenname="AuctionTestToken$image_index"
tokenname_hex=$(echo -n "$tokenname" | xxd -ps | tr -d '\n')

echo "Token name: $tokenname ($tokenname_hex)"

cat << EOF > "$methadata_file_name"
{
    "721": {
        "$policy_id": {
            "$tokenname": {
                "name": "$tokenname",
                "image": "ipfs://${images[image_index]}",
                "mediaType": "image/jpeg"
            }
        }
    }
}
EOF

set -x

cardano-cli latest transaction build \
    --testnet-magic 2 \
    --out-file "$tx_unsigned_name" \
    --tx-in $utxo \
    --change-address "$wallet_address" \
    --mint "1 $policy_id.$tokenname_hex" \
    --mint-script-file "$policy_script_name" \
    --required-signer-hash "$policy_key_hash" \
    --metadata-json-file "$methadata_file_name" \
    --tx-out "$(wallets_get_address wallet_nft)+1193870+1 ${policy_id}.${tokenname_hex}" \

#  --tx-out "$my_nami_address"+"1202490"+"1 $policyid.$tokenname1" \
#  --tx-in 'c5ba91bf3a84e71fe8d16a3edaacf9466be598174653a4404b5471b8f84fccb3#0' \
#  --tx-out "$roberto_address"+"10000000"+"12 $policyid.$tokenname1" \

cardano-cli latest transaction sign \
    --testnet-magic 2 \
    --tx-body-file "$tx_unsigned_name" \
    --out-file "$tx_signed_name" \
    --signing-key-file "$policy_signing_key_file" \
    --signing-key-file "$utxo_signing_key_file" \

cardano-cli latest transaction submit \
    --testnet-magic 2 \
    --tx-file "$tx_signed_name"

rm "$tx_unsigned_name"
rm "$tx_signed_name"
