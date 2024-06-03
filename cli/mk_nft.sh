#!/usr/bin/env bash
# shellcheck disable=SC1091

. ./functions.sh

tx_unsigned_name=$(mktemp)
# tx_signed_name=$(mktemp)
 
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

wallet_address=$(wallets_get_address wallet)

policy_script_name="nft_policy.script"
policy_wallet=walletB
policy_key_hash=$(wallets_get_vkey_hash "$policy_wallet")

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
tokenname="AuctionTestToken"
tokenname_hex=$(echo -n "$tokenname" | xxd -ps | tr -d '\n')

echo "Token name: $tokenname ($tokenname_hex)"

for image_index in "${!images[@]}" ; do
	echo "$image_index: ${images[image_index]}"
done

image_index=0

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

cardano-cli transaction build \
  --babbage-era \
  --testnet-magic 2 \
  --tx-in '0a8d2bf157c0e3eb44f224a830716443dd450f5ac02bb85a89b490add5ccafb8#0' \
  --change-address "$wallet_address" \
  --out-file "$tx_unsigned_name" \
  --mint "1 $policy_id.$tokenname_hex" \
  --mint-script-file "$policy_script_name" \
  --required-signer-hash "$policy_key_hash" \
  --metadata-json-file "$methadata_file_name" \

#  --tx-out "$my_nami_address"+"1202490"+"1 $policyid.$tokenname1" \
#  --tx-in 'c5ba91bf3a84e71fe8d16a3edaacf9466be598174653a4404b5471b8f84fccb3#0' \
#  --tx-out "$roberto_address"+"10000000"+"12 $policyid.$tokenname1" \

# cardano-cli transaction sign \
#   --tx-body-file "$tx_unsigned_name" \
#   --signing-key-file "$wallet_signing_key" \
#   --testnet-magic 2 \
#   --out-file "$tx_signed_name"
# 
# cardano-cli transaction submit \
#  --tx-file "$tx_signed_name"
#  --testnet-magic 2 \

rm "$tx_unsigned_name"
# rm "$tx_signed_name"

# https://preview.cexplorer.io/tx/ca94da53136911c516520dffefe56dbdb5b126fbd222d6d3d188d3c1d04382b7




