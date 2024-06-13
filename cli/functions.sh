#!/usr/bin/env bash
# shellcheck disable=SC2317,SC2034

CARDANO_NODE_SOCKET_PATH=$(pwd)/state-node-preview/node.socket
export CARDANO_NODE_SOCKET_PATH

YELLOW=$(tput setaf 3)
RESET=$(tput sgr0)

function error()
{
	local msg="$1"
	echo -e "\n${YELLOW}${msg}${RESET}\n" >&2
	exit
}

WALLETS="wallet wallet_nft"

function wallets_get_address() {
	local wallet="$1"
	cat "$WALLETS_DIR/$wallet/payment.addr"
}

function wallets_get_vkey_hash() {
	local wallet="$1"
	cat "$WALLETS_DIR/$wallet/enterprise.vkey.hash"
}

function wallets_get_signing_key_file() {
	local wallet="$1"
	echo "$WALLETS_DIR/$wallet/enterprise.skey"
}

function check_utxo() {

	local wallet="$1"

	address=$(wallets_get_address "$wallet")
	cardano-cli query utxo --address "$address" --testnet-magic 2
}

function check_utxo_contract() {

	address=$(cat contract_address.txt)
	cardano-cli query utxo --address "$address" --testnet-magic 2
}

