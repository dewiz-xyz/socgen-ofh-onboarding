#!/usr/bin/env bash

set -eo pipefail

if [[ ${DEBUG} ]]; then
	set -x
fi

die() {
  echo "$1" >&2
  exit 1
}

# All contracts are output to `out/addresses.json` by default
OUT_DIR=${OUT_DIR:-$PWD/out}
ADDRESSES_FILE=${ADDRESSES_FILE:-$OUT_DIR/"addresses.json"}
# default to localhost rpc
ETH_RPC_URL=${ETH_RPC_URL:-http://localhost:8545}

# green log helper
GREEN='\033[0;32m'
NC='\033[0m' # No Color
log() {
	printf '%b\n' "${GREEN}${*}${NC}"
	echo ""
}

# Coloured output helpers
if command -v tput >/dev/null 2>&1; then
	if [ $(($(tput colors 2>/dev/null))) -ge 8 ]; then
		# Enable colors
		TPUT_RESET="$(tput sgr 0)"
		TPUT_YELLOW="$(tput setaf 3)"
		TPUT_RED="$(tput setaf 1)"
		TPUT_BLUE="$(tput setaf 4)"
		TPUT_GREEN="$(tput setaf 2)"
		TPUT_WHITE="$(tput setaf 7)"
		TPUT_BOLD="$(tput bold)"
	fi
fi

# ensure ETH_FROM is set and give a meaningful error message
[[ -z "$ETH_FROM" ]] && die "ETH_FROM not found, please set it and re-run the last command."

# Make sure address is checksummed
[ "$ETH_FROM" != "$(seth --to-checksum-address "$ETH_FROM")" ] && \
	die "ETH_FROM not checksummed, please format it with 'seth --to-checksum-address <address>'"

# Setup addresses file
cat >"$ADDRESSES_FILE" <<EOF
{
    "DEPLOYER": "$ETH_FROM"
}
EOF


deploy() {
	local FILE_NAME="$1"
	local NAME="$2"
	local ARGS=${@:3}

	# find file path
	local CONTRACT_PATH=$(find . -name $FILE_NAME.sol)
	CONTRACT_PATH=${CONTRACT_PATH:2}

	# select the filename and the contract in it
	local PATTERN=".contracts[\"$CONTRACT_PATH\"].$NAME"

	# get the constructor's signature
	local ABI=$(jq -r "$PATTERN.abi" out/dapp.sol.json)
	local SIG=$(echo "$ABI" | seth --abi-constructor)

	# get the bytecode from the compiled file
	local BYTECODE=0x$(jq -r "$PATTERN.evm.bytecode.object" out/dapp.sol.json)

	# estimate gas
	local GAS=$(seth estimate --create "$BYTECODE" "$SIG" $ARGS --rpc-url "$ETH_RPC_URL")

	# deploy
	local ADDRESS=$(dapp create "$NAME" $ARGS -- --gas "$GAS" --rpc-url "$ETH_RPC_URL")

	# save the addrs to the json
	# TODO: It'd be nice if we could evolve this into a minimal versioning system
	# e.g. via commit / chainid etc.
	saveContract "$NAME" "$ADDRESS"

	echo "$ADDRESS"
}

# Call as `saveContract ContractName 0xYourAddress` to store the contract name
# & address to the addresses json file
saveContract() {
	# create an empty json if it does not exist
	if [[ ! -e $ADDRESSES_FILE ]]; then
		echo "{}" >"$ADDRESSES_FILE"
	fi

	local result=$(cat "$ADDRESSES_FILE" | jq -r ". + {\"$1\": \"$2\"}")
	printf %s "$result" >"$ADDRESSES_FILE"
}

int(){
	expr ${1:-} : '[^0-9]*\([0-9]*\)' 2>/dev/null||:;
}

estimate_gas() {
	local FILE_NAME="$1"
	local NAME="$2"
	local ARGS=${@:3}

	# select the filename and the contract in it
	local PATTERN=".contracts[\"src/$FILE_NAME.sol\"].$NAME"

	# get the constructor's signature
	local ABI=$(jq -r "$PATTERN.abi" out/dapp.sol.json)
	local SIG=$(echo "$ABI" | seth --abi-constructor)

	# get the bytecode from the compiled file
	local BYTECODE=0x$(jq -r "$PATTERN.evm.bytecode.object" out/dapp.sol.json)
	# estimate gas
	local GAS=$(seth estimate --create "$BYTECODE" "$SIG" $ARGS --rpc-url "$ETH_RPC_URL")

	local TXPRICE_RESPONSE=$(curl -sL 'https://api.etherscan.io/api?module=gastracker&action=gasoracle&apikey='${ETHERSCAN_API_KEY})
	local status="$(jq '.status' <<<"$TXPRICE_RESPONSE")"

	if [ "$status" == "1" ]; then
		die "Could not get gas information from ${TPUT_BOLD}etherscan.io${TPUT_RESET}"
	else
		local fast="$(int "$(jq '.result.FastGasPrice' <<<"$TXPRICE_RESPONSE")")"
		local standard="$(int "$(jq '.result.ProposeGasPrice' <<<"$TXPRICE_RESPONSE")")"
		local slow="$(int "$(jq '.result.SafeGasPrice' <<<"$TXPRICE_RESPONSE")")"
		# local basefee="$(int "$(jq '.result.suggestBaseFee' <<<"$TXPRICE_RESPONSE")")"
		echo "Gas prices from ${TPUT_BOLD}txprice.com${TPUT_RESET}: https://api.etherscan.io"
		echo " \
     		${TPUT_RED}Fast: $fast gwei${TPUT_RESET}
     		${TPUT_YELLOW}Standard: $standard gwei${TPUT_RESET}
     		${TPUT_GREEN}Slow: $slow gwei${TPUT_RESET}" | column -t
		local size=$(contract_size "$NAME")
		echo ""
		echo "Estimated Gas cost for deployment of $NAME: ${TPUT_BOLD}$GAS${TPUT_RESET} units of gas"
		echo "Contract Size: ${size} bytes"
		echo "Total cost for deployment:"
		local fast_cost=$(bc <<<"scale=5; $GAS*$fast/10^9")
		local standard_cost=$(bc <<<"scale=5; $GAS*$standard/10^9")
		local slow_cost=$(bc <<<"scale=5; $GAS*$slow/10^9")
		echo " \
     		${TPUT_RED}Fast: $fast_cost ETH${TPUT_RESET}
     		${TPUT_YELLOW}Standard: $standard_cost ETH${TPUT_RESET}
     		${TPUT_GREEN}Slow: $slow_cost ETH ${TPUT_RESET}" | column -t
	fi
}

contract_size() {
	FILE_NAME="$1"
	NAME=${2:-$1}
	# select the filename and the contract in it
	PATTERN=".contracts[\"src/$FILE_NAME.sol\"].$NAME"

	# get the bytecode from the compiled file
	BYTECODE=0x$(jq -r "$PATTERN.evm.bytecode.object" out/dapp.sol.json)
	length=$(echo "$BYTECODE" | wc -m)
	echo $(($length / 2))
}
