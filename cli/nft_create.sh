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
