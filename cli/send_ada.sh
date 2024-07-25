#!/usr/bin/env bash
# shellcheck disable=SC1091

. ./functions.sh

tx_unsigned_name=$(mktemp)
tx_signed_name=$(mktemp)

cardano-cli latest transaction build \
    --testnet-magic 2 \
    --tx-in '18ca330153f88b742675c480609f36a97c54e2a2bc28474c26744fae79fe2040#1' \
    --tx-in '18ca330153f88b742675c480609f36a97c54e2a2bc28474c26744fae79fe2040#2' \
    --tx-in '7719b12054b3b5e90b10d4f74aabc041689f16cb9916411f7d7aa80aae871e47#1' \
    --tx-in '85925be2a9e87cd4fb4b8fbeecef8e944062e5f88e73b754c215d57f400d309d#2' \
    --change-address "$(wallets_get_address wallet)" \
    --out-file "$tx_unsigned_name" \
    || exit 1

#   --tx-out "$(wallets_get_address wallet_attic)+1193870+4 232b62004de2e378406f8a0161825def83e1834b76df240324466766.41756374696f6e54657374546f6b656e30" \
#   --tx-out "$(wallets_get_address wallet)+10000000000" \
#   --tx-out "$(wallets_get_address wallet)+10000000000" \
#   --tx-out "$(wallets_get_address wallet_attic)+1193870+7 232b62004de2e378406f8a0161825def83e1834b76df240324466766.41756374696f6e54657374546f6b656e30" \

cardano-cli latest transaction sign \
    --testnet-magic 2 \
    --tx-body-file "$tx_unsigned_name" \
    --signing-key-file "$(wallets_get_signing_key_file wallet_nft)" \
    --signing-key-file "$(wallets_get_signing_key_file wallet)" \
    --out-file "$tx_signed_name" \
    || exit 1

cardano-cli latest transaction submit \
    --testnet-magic 2 \
    --tx-file "$tx_signed_name" \
    || exit 1

rm "$tx_unsigned_name"
rm "$tx_signed_name"
