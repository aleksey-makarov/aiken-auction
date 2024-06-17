#!/usr/bin/env bash
# shellcheck disable=SC1091

. ./functions.sh

tx_unsigned_name=$(mktemp)
tx_signed_name=$(mktemp)

cardano-cli latest transaction build \
    --testnet-magic 2 \
    --tx-in '4a8e34c3c8e2a7a43b7314a4ddb49e7471d913b019ee056be471940e1ff5597d#0' \
    --tx-in '631d83c35b84176f53584fe9b7c822fc346e3e7cb42c6f14b101edd0830430d1#1' \
    --tx-in 'a60b66a483f2fca572c7ce413d1944ab790d8b05bd25e15d0a18d548885eda06#1' \
    --tx-in '4a8e34c3c8e2a7a43b7314a4ddb49e7471d913b019ee056be471940e1ff5597d#1' \
    --tx-in '631d83c35b84176f53584fe9b7c822fc346e3e7cb42c6f14b101edd0830430d1#0' \
    --tx-in '631d83c35b84176f53584fe9b7c822fc346e3e7cb42c6f14b101edd0830430d1#2' \
    --tx-in 'a60b66a483f2fca572c7ce413d1944ab790d8b05bd25e15d0a18d548885eda06#0' \
    --tx-in 'a60b66a483f2fca572c7ce413d1944ab790d8b05bd25e15d0a18d548885eda06#2' \
    --tx-out "$(wallets_get_address wallet_attic)+1193870+3 232b62004de2e378406f8a0161825def83e1834b76df240324466766.41756374696f6e54657374546f6b656e30" \
    --change-address "$(wallets_get_address wallet)" \
    --out-file "$tx_unsigned_name" \
    || exit 1

#     --tx-out "$(wallets_get_address wallet)+10000000000" \
#     --tx-out "$(wallets_get_address wallet)+10000000000" \
#    --tx-out "$(wallets_get_address wallet_attic)+1193870+7 232b62004de2e378406f8a0161825def83e1834b76df240324466766.41756374696f6e54657374546f6b656e30" \

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
