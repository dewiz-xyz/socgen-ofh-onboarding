#!/bin/bash

set -eo pipefail

source "${BASH_SOURCE%/*}/common.sh"
# shellcheck disable=SC1091
source "${BASH_SOURCE%/*}/build-env-addresses.sh" goerli >/dev/null 2>&1

[[ "$ETH_RPC_URL" && "$(seth chain)" == "goerli" ]] || die "Please set a goerli ETH_RPC_URL"
[[ -z "$MIP21_LIQUIDATION_ORACLE" ]] || die 'Please set the MIP21_LIQUIDATION_ORACLE env var'

export ETH_GAS=6000000

# TODO: confirm if name/symbol is going to follow the RWA convention
# TODO: confirm with DAO at the time of mainnet deployment if OFH will indeed be 007
[[ -z "$NAME" ]] && NAME="RWA-008-AT2"
[[ -z "$SYMBOL" ]] && SYMBOL="RWA008AT2"
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
ILK_ENCODED=$(seth --to-bytes32 "$(seth --from-ascii "$ILK")")

# build it
make build

[[ -z "$OPERATOR" ]] && OPERATOR=$(dapp create ForwardProxy) # using generic forward proxy for goerli
[[ -z "$MATE" ]] && MATE=$(dapp create ForwardProxy)         # using generic forward proxy for goerli

# tokenize it
[[ -z "$RWA_TOKEN" ]] && {
    RWA_TOKEN=$(dapp create RwaToken "\"$NAME\"" "\"$SYMBOL\"")
    seth send "$RWA_TOKEN" 'transfer(address,uint256)' "$OPERATOR" $(seth --to-wei 1 ETH)
}

# route it
[[ -z "$RWA_OUTPUT_CONDUIT" ]] && {
    RWA_OUTPUT_CONDUIT=$(dapp create RwaOutputConduit2 "$MCD_DAI")

    seth send "$RWA_OUTPUT_CONDUIT" 'rely(address)' "$MCD_PAUSE_PROXY" &&
        seth send "$RWA_OUTPUT_CONDUIT" 'deny(address)' "$ETH_FROM"
}

# join it
RWA_JOIN=$(dapp create AuthGemJoin "$MCD_VAT" "$ILK_ENCODED" "$RWA_WRAPPER_TOKEN")
seth send "$RWA_JOIN" 'rely(address)' "$MCD_PAUSE_PROXY" &&
    seth send "$RWA_JOIN" 'deny(address)' "$ETH_FROM"

# urn it
RWA_URN=$(dapp create RwaUrn "$MCD_VAT" "$MCD_JUG" "$RWA_JOIN" "$MCD_JOIN_DAI" "$RWA_OUTPUT_CONDUIT")
seth send "$RWA_URN" 'rely(address)' "$MCD_PAUSE_PROXY" &&
    seth send "$RWA_URN" 'deny(address)' "$ETH_FROM"

[[ -z "$RWA_URN_PROXY_VIEW" ]] && {
    RWA_URN_PROXY_VIEW=$(dapp create RwaUrnProxyView)
    echo "RWA_URN_PROXY_VIEW: ${RWA_URN_PROXY_VIEW}" >&2
}

# connect it
[[ -z "$RWA_INPUT_CONDUIT" ]] && {
    RWA_INPUT_CONDUIT=$(dapp create RwaInputConduit2 "$MCD_DAI" "$RWA_URN")

    seth send "$RWA_INPUT_CONDUIT" 'rely(address)' "$MCD_PAUSE_PROXY" &&
        seth send "$RWA_INPUT_CONDUIT" 'deny(address)' "$ETH_FROM"
}

# print it
cat << JSON
{
    "SYMBOL": "${SYMBOL}",
    "NAME": "${NAME}",
    "ILK": "${ILK}",
    "MIP21_LIQUIDATION_ORACLE": "${MIP21_LIQUIDATION_ORACLE}",
    "${SYMBOL}": "${RWA_WRAPPER_TOKEN}",
    "MCD_JOIN_${SYMBOL}_${LETTER}": "${RWA_JOIN}",
    "${SYMBOL}_${LETTER}_URN": "${RWA_URN}",
    "${SYMBOL}_${LETTER}_INPUT_CONDUIT": "${RWA_INPUT_CONDUIT}",
    "${SYMBOL}_${LETTER}_OUTPUT_CONDUIT": "${RWA_OUTPUT_CONDUIT}",
    "${SYMBOL}_${LETTER}_OPERATOR": "${OPERATOR}",
    "${SYMBOL}_${LETTER}_MATE": "${MATE}"
}
JSON
