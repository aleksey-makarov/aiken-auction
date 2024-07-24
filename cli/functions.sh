#!/usr/bin/env bash
# shellcheck disable=SC2317,SC2034

CARDANO_NODE_SOCKET_PATH="$STATE_NODE_DIR/state-node-preview/node.socket"
export CARDANO_NODE_SOCKET_PATH

YELLOW=$(tput setaf 3)
RESET=$(tput sgr0)

WALLETS="wallet wallet_nft"

S_IN_MIN=60
S_IN_HOUR=$((S_IN_MIN * 60))
S_IN_DAY=$((S_IN_HOUR * 24))

SHELLY_UNIX=1596491091
SHELLY_SLOT=4924800

PREVIEW_UNIX=1708263608
PREVIEW_SLOT=41607608

function preview_slot_to_unix ()
{
	slot="$1"
	echo $((slot - PREVIEW_SLOT + PREVIEW_UNIX))
}

function preview_unix_to_slot ()
{
	unix="$1"
	echo $((unix - PREVIEW_UNIX + PREVIEW_SLOT))
}

function error()
{
	local msg="$1"
	echo -e "\n${YELLOW}${msg}${RESET}\n" >&2
	exit
}

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
