#!/usr/bin/env bash
# shellcheck disable=SC2317

export CARDANO_NODE_SOCKET_PATH=/run/cardano-node/node.socket
export WALLETS_DIR=/home/amakarov/cardano/work

YELLOW=$(tput setaf 3)
RESET=$(tput sgr0)

function error()
{
	local msg="$1"
    echo -e "\n${YELLOW}${msg}${RESET}\n" >&2
    exit
}

function wallets_get_address() {
	local wallet="$1"

	if [ ! -e "$WALLETS_DIR/$wallet" ]; then
		error "wallet \"$wallet\" does not exist"
	fi

	cat "$WALLETS_DIR/$wallet/payment.addr"
}

function wallets_get_vkey_hash() {
	local wallet="$1"

	if [ ! -e "$WALLETS_DIR/$wallet" ]; then
		error "wallet \"$wallet\" does not exist"
	fi

	cat "$WALLETS_DIR/$wallet/enterprise.vkey.hash"
}

function check_utxo() {

	local wallet="$1"

	if [ $# -ne 1 ] ; then
	    error "usage: check_utxo wallet_name"
	fi

	address=$(wallets_get_address "$wallet")
	cardano-cli query utxo --address "$address" --testnet-magic 2
}
