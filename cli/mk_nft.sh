#!/usr/bin/env bash
# shellcheck disable=SC1091

. ./functions.sh

# tx_unsigned_name=$(mktemp)
# tx_signed_name=$(mktemp)
 
#wrap terminal
# echo -ne "\x1b[?7h"

#unwrap terminal
# echo -ne "\x1b[?7l"

# "01" "QmPwTdg9xGSEroAggB5sW6VLfyAVzmGYVxWnrh5FccTfYF"
# "02" "QmYWkzCfy3sZT9ExHFzzBXncfLw434tYVfhuzxvNFR7k1G"
# "03" "QmSJujeMVea3bw39jFmzqUrvWfPPhhFtYvcoM9Fd26ecXn"
# "04" "QmYJwCVQAMegQC6mWJqNrA3DmRtKC48moB5NbQgwFCbdwV"
# "05" "QmYusLQ1AxcWVmNaXxeHvciCvn4SuJfAWwQRU7jASWWoaf"
# "06" "Qmd2hMufefhxLoqzphnPUEd4GJqrYBQ7VPYzLzZfJuEvH5"
# "07" "QmSma1PXmTQqEuwMoW16mYY6BJ1w9ErNTqExPxKfepTnhZ"
# "08" "QmQjmAPQhPqVdyMWrmVJcfJoJocpz8x86jAMvHCcfDPbbE"
# "09" "QmQpjVG4Fgo6ft5L7XTWupGpj1aijW8e8BZ8av4YqZtdYS"
# "10" "QmRa55E1f7wecRJYFNoUkFReopuTyQyRcdAJxodb4UGWqM"

policy_script_name="nft_policy.script"
policy_wallet=walletB
policy_key_hash=$(cat "$WALLETS_DIR/$policy_wallet/enterprise.vkey.hash")

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

cat << EOF > "$methadata_file_name"
{
    "721": {
        "$policy_id": {
            "$tokenname": {
                "name": "Sima the cat",
                "image": "ipfs://QmPuc6FFXbPNwzN8Epzn2FyNSqhKmJv9xQcHAKRrR4vxLY",
                "mediaType": "image/jpeg"
            }
        }
    }
}
EOF

cardano-cli transaction build \
  --babbage-era \
  --testnet-magic 2 \
  --tx-in '5806e2dbaddc12b5d918fb2ecb57f33934bf06f7c458e8af36809a41721c8962#1' \
  --change-address "$wallet_address" \
  --out-file "$tx_unsigned_name" \
  --mint "1 $policy_id.$tokenname_hex" \
  --mint-script-file "$policy_script_name" \
  --required-signer-hash "$wallet_key_hash" \
  --metadata-json-file "$methadata_file_name" \

exit

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
rm "$tx_signed_name"

# https://preview.cexplorer.io/tx/ca94da53136911c516520dffefe56dbdb5b126fbd222d6d3d188d3c1d04382b7




