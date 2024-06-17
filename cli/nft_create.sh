#!/usr/bin/env bash
# shellcheck disable=SC1091

. ./functions.sh

image_index=0

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

cat << EOF > nft_script.json
{
	"type" : "all",
	"scripts" : [
		{
			"type" : "sig",
			"keyHash" : "$(wallets_get_vkey_hash wallet_nft)"
		}
	]
}
EOF

policy_id=$(cardano-cli transaction policyid --script-file nft_script.json)
echo "Policy ID: $policy_id"

tokenname="AuctionTestToken$image_index"
tokenname_hex=$(echo -n "$tokenname" | xxd -ps | tr -d '\n')

echo "Token name: $tokenname ($tokenname_hex)"

cat << EOF > nft_methadata.json
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

echo "$tokenname_hex" > nft_name_hex.txt
echo "$policy_id" > nft_policy_id.txt

exit

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
