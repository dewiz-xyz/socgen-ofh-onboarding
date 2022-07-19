#!/bin/bash
#
# bash scripts/deploy-mainnet.sh

set -eo pipefail

source "${BASH_SOURCE%/*}/_common.sh"
# shellcheck disable=SC1091
source "${BASH_SOURCE%/*}/build-env-addresses.sh" mainnet >/dev/null 2>&1

[[ "$ETH_RPC_URL" && "$(cast chain)" == "ethlive" ]] || die "Please set a mainnet ETH_RPC_URL"
[[ -z "$MIP21_LIQUIDATION_ORACLE" ]] && die 'Please set the MIP21_LIQUIDATION_ORACLE env var'
[[ -z "$OPERATOR" ]] && die 'Please set the OPERATOR env var'
[[ -z "$MATE" ]] && die "Please set the MATE env var"

# TODO: confirm for mainnet deployment
export ETH_GAS=6000000

# TODO: confirm if name/symbol is going to follow the RWA convention
# TODO: confirm with DAO at the time of mainnet deployment if OFH will indeed be 007
[[ -z "$NAME" ]] && NAME="RWA-008"
[[ -z "$SYMBOL" ]] && SYMBOL="RWA008"
#
# WARNING (2021-09-08): The system cannot currently accomodate any LETTER beyond
# "A".  To add more letters, we will need to update the PIP naming convention
# to include the letter.  Unfortunately, while fixing this on-chain and in our
# code would be easy, RWA001 integrations may already be using the old PIP
# naming convention.  So, before we can have new letters we must:
# 1. Change the existing PIP naming convention
# 2. Change all the places that depend on that convention (this script included)
# 3. Make sure all integrations are ready to accomodate that new PIP name.
# ! TODO: check with team/PE if this is still the case
#
[[ -z "$LETTER" ]] && LETTER="A"

ILK="${SYMBOL}-${LETTER}"
ILK_ENCODED=$(cast --to-bytes32 "$(cast --from-ascii ${ILK})")

# build it
make build

FORGE_DEPLOY="${BASH_SOURCE%/*}/forge-deploy.sh"
CAST_SEND="${BASH_SOURCE%/*}/cast-send.sh"

# tokenize it
[[ -z "$RWA_TOKEN" ]] && {
	debug 'WARNING: `$RWA_TOKEN` not set. Deploying it...'
	TX=$($CAST_SEND "${RWA_TOKEN_FAB}" 'createRwaToken(string,string,address)' "$NAME" "$SYMBOL" "$OPERATOR")
	debug "TX: $TX"

	RECEIPT="$(cast receipt --json $TX)"
	TX_STATUS="$(jq -r '.status' <<<"$RECEIPT")"
	[[ "$TX_STATUS" != "0x1" ]] && die "Failed to create ${SYMBOL} token in tx ${TX}."

	RWA_TOKEN="$(jq -r ".logs[0].address" <<<"$RECEIPT")"
	debug "${SYMBOL}: ${RWA_TOKEN}"
}

# route it
[[ -z "$RWA_OUTPUT_CONDUIT" ]] && {
	RWA_OUTPUT_CONDUIT=$($FORGE_DEPLOY --verify RwaConduits:RwaOutputConduit2 --constructor-args "$MCD_DAI")
    debug "${SYMBOL}_${LETTER}_OUTPUT_CONDUIT": "${RWA_OUTPUT_CONDUIT}"

	$CAST_SEND "$RWA_OUTPUT_CONDUIT" 'rely(address)' "$MCD_PAUSE_PROXY" &&
		$CAST_SEND "$RWA_OUTPUT_CONDUIT" 'deny(address)' "$ETH_FROM"
}

[[ -z "$RWA_JOIN" ]] && {
	# join it
	RWA_JOIN=$($FORGE_DEPLOY --verify AuthGemJoin --constructor-args "$MCD_VAT" "$ILK_ENCODED" "$RWA_TOKEN")
    debug "MCD_JOIN_${SYMBOL}_${LETTER}": "${RWA_JOIN}"

	$CAST_SEND "$RWA_JOIN" 'rely(address)' "$MCD_PAUSE_PROXY" &&
		$CAST_SEND "$RWA_JOIN" 'deny(address)' "$ETH_FROM"
}

[[ -z "$RWA_URN" ]] && {
	# urn it
	RWA_URN=$($FORGE_DEPLOY --verify RwaUrn2 --constructor-args "$MCD_VAT" "$MCD_JUG" "$RWA_JOIN" "$MCD_JOIN_DAI" "$RWA_OUTPUT_CONDUIT")
    debug "${SYMBOL}_${LETTER}_URN: ${RWA_URN}"

	$CAST_SEND "$RWA_URN" 'rely(address)' "$MCD_PAUSE_PROXY" &&
		$CAST_SEND "$RWA_URN" 'deny(address)' "$ETH_FROM"
}

[[ -z "$RWA_URN_PROXY_ACTIONS" ]] && {
	RWA_URN_PROXY_ACTIONS=$($FORGE_DEPLOY --verify RwaUrnProxyActions) --constructor-args
	debug "RWA_URN_PROXY_ACTIONS: ${RWA_URN_PROXY_ACTIONS}"
}

# connect it
[[ -z "$RWA_INPUT_CONDUIT" ]] && {
	RWA_INPUT_CONDUIT=$($FORGE_DEPLOY --verify RwaConduits:RwaInputConduit2 --constructor-args "$MCD_DAI" "$RWA_URN")
	debug "${SYMBOL}_${LETTER}_INPUT_CONDUIT: ${RWA_INPUT_CONDUIT}"

	$CAST_SEND "$RWA_INPUT_CONDUIT" 'rely(address)' "$MCD_PAUSE_PROXY" &&
		$CAST_SEND "$RWA_INPUT_CONDUIT" 'deny(address)' "$ETH_FROM"
}

# print it
cat <<JSON
{
    "MIP21_LIQUIDATION_ORACLE": "${MIP21_LIQUIDATION_ORACLE}",
    "RWA_TOKEN_FAB": "${RWA_TOKEN_FAB}",
    "RWA_URN_PROXY_ACTIONS": "${RWA_URN_PROXY_ACTIONS}",
    "SYMBOL": "${SYMBOL}",
    "NAME": "${NAME}",
    "ILK": "${ILK}",
    "${SYMBOL}": "${RWA_TOKEN}",
    "MCD_JOIN_${SYMBOL}_${LETTER}": "${RWA_JOIN}",
    "${SYMBOL}_${LETTER}_URN": "${RWA_URN}",
    "${SYMBOL}_${LETTER}_INPUT_CONDUIT": "${RWA_INPUT_CONDUIT}",
    "${SYMBOL}_${LETTER}_OUTPUT_CONDUIT": "${RWA_OUTPUT_CONDUIT}",
    "${SYMBOL}_${LETTER}_OPERATOR": "${OPERATOR}",
    "${SYMBOL}_${LETTER}_MATE": "${MATE}"
}
JSON
