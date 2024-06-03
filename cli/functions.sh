#!/usr/bin/env bash
# shellcheck disable=SC2317

export CARDANO_NODE_SOCKET_PATH=/run/cardano-node/node.socket
export WALLETS_DIR=/home/amakarov/cardano/work

YELLOW=$(tput setaf 3)
RESET=$(tput sgr0)

function error()
{
        msg="$1"
        echo
        echo -e "${YELLOW}${msg}${RESET}"
        echo
}

function check_utxo() {

	if [ $# -ne 1 ] ; then
	    error "usage: check_utxo wallet_name"
	    return
	fi

	wallet_name="$1"

	if [ ! -e "$WALLETS_DIR/$wallet_name" ]; then
    	error "wallet $wallet_name does not exist"
    	return
	fi

	address=$(cat "$WALLETS_DIR/$wallet_name"/payment.addr)
	cardano-cli query utxo --address "$address" --testnet-magic 2
}
