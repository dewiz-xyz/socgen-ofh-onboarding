#!/bin/bash
set -eo pipefail

source "${BASH_SOURCE%/*}/common.sh"
# shellcheck disable=SC1091
source "${BASH_SOURCE%/*}/build-env-addresses.sh" ces-goerli >/dev/null 2>&1

[[ "$ETH_RPC_URL" && "$(seth chain)" == "goerli" ]] || die "Please set a goerli ETH_RPC_URL"

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

# [[ -z "$MIP21_LIQUIDATION_ORACLE" ]] && MIP21_LIQUIDATION_ORACLE="0xDEADBEEFDEADBEEFDEADBEEFDEADBEEFDEADBEEF"
# TODO: confirm liquidations handling - no liquidations for the time being

ILK="${SYMBOL}-${LETTER}"
echo "ILK: ${ILK}" >&2
ILK_ENCODED=$(seth --to-bytes32 "$(seth --from-ascii "$ILK")")

# build it
make build

# tokenize it
[[ -z "$RWA_TOKEN" ]] && {
    echo 'WARNING: `$RWA_TOKEN` not set. Deploying it...' >&2
    TX=$(seth send --async "${RWA_TOKEN_FACTORY}" 'createRwaToken(string,string,address)' \"$NAME\" \"$SYMBOL\" "$MCD_PAUSE_PROXY")
    echo "TX: $TX" >&2

    RECEIPT="$(seth receipt $RWA_TOKEN_CREATE_TX)"
    TX_STATUS="$(awk '/^status/ { print $2 }' <<<"$RECEIPT")"
    [[ "$TX_STATUS" != "1" ]] && die "Failed to create ${SYMBOL} token in tx ${TX}."

    RWA_TOKEN="$(seth call "$RWA_TOKEN_FACTORY" "tokenAddresses(bytes32)(address)" $(seth --from-ascii "$SYMBOL"))"
}

echo "${SYMBOL}: ${RWA_TOKEN}" >&2

[[ -z "$OPERATOR" ]] && OPERATOR=$(dapp create ForwardProxy) # using generic forward proxy for goerli
echo "${SYMBOL}_${LETTER}_OPERATOR: ${OPERATOR}" >&2

[[ -z "$MATE" ]] && MATE=$(dapp create ForwardProxy) # using generic forward proxy for goerli
echo "${SYMBOL}_${LETTER}_MATE: ${MATE}" >&2

# route it
[[ -z "$RWA_OUTPUT_CONDUIT" ]] && {
    RWA_OUTPUT_CONDUIT=$(dapp create RwaOutputConduit2 "$MCD_DAI")
    echo "${SYMBOL}_${LETTER}_OUTPUT_CONDUIT: ${RWA_OUTPUT_CONDUIT}" >&2

    # trust addresses for goerli
    seth send "$RWA_OUTPUT_CONDUIT" 'rely(address)' "$MCD_PAUSE_PROXY" &&
        seth send "$RWA_OUTPUT_CONDUIT" 'deny(address)' "$ETH_FROM"

} || {
    echo "${SYMBOL}_${LETTER}_OUTPUT_CONDUIT: ${RWA_OUTPUT_CONDUIT}" >&2
}

# join it
RWA_JOIN=$(dapp create AuthGemJoin "$MCD_VAT" "$ILK_ENCODED" "$RWA_TOKEN")
echo "MCD_JOIN_${SYMBOL}_${LETTER}: ${RWA_JOIN}" >&2
seth send "$RWA_JOIN" 'rely(address)' "$MCD_PAUSE_PROXY" &&
    seth send "$RWA_JOIN" 'deny(address)' "$ETH_FROM"

# urn it
RWA_URN=$(dapp create RwaUrn "$MCD_VAT" "$MCD_JUG" "$RWA_JOIN" "$MCD_JOIN_DAI" "$RWA_OUTPUT_CONDUIT")
echo "${SYMBOL}_${LETTER}_URN: ${RWA_URN}" >&2
seth send "$RWA_URN" 'rely(address)' "$MCD_PAUSE_PROXY" &&
    seth send "$RWA_URN" 'deny(address)' "$ETH_FROM"

[[ -z "$RWA_URN_PROXY_ACTIONS" ]] && {
    RWA_URN_PROXY_ACTIONS=$(dapp create RwaUrnProxyActions)
    echo "RWA_URN_PROXY_ACTIONS: ${RWA_URN_PROXY_ACTIONS}" >&2
}

# connect it
[[ -z "$RWA_INPUT_CONDUIT" ]] && {
    RWA_INPUT_CONDUIT=$(dapp create RwaInputConduit2 "$MCD_DAI" "$RWA_URN")
    echo "${SYMBOL}_${LETTER}_INPUT_CONDUIT: ${RWA_INPUT_CONDUIT}" >&2

    seth send "$RWA_INPUT_CONDUIT" 'rely(address)' "$MCD_PAUSE_PROXY" &&
        seth send "$RWA_INPUT_CONDUIT" 'deny(address)' "$ETH_FROM"
} || {
    echo "${SYMBOL}_${LETTER}_INPUT_CONDUIT: ${RWA_INPUT_CONDUIT}" >&2
}

# price it
[[ -z "$MIP21_LIQUIDATION_ORACLE" ]] && {
    MIP21_LIQUIDATION_ORACLE=$(dapp create RwaLiquidationOracle "$MCD_VAT" "$MCD_VOW")
    echo "MIP21_LIQUIDATION_ORACLE: ${MIP21_LIQUIDATION_ORACLE}" >&2

    seth send "$MIP21_LIQUIDATION_ORACLE" 'rely(address)' "$MCD_PAUSE_PROXY" &&
        seth send "$MIP21_LIQUIDATION_ORACLE" 'deny(address)' "$ETH_FROM"
} || {
    echo "MIP21_LIQUIDATION_ORACLE: ${MIP21_LIQUIDATION_ORACLE}" >&2
}

cat <<JSON
{
    "MIP21_LIQUIDATION_ORACLE": "${MIP21_LIQUIDATION_ORACLE}",
    "RWA_TOKEN_FACTORY": "${RWA_TOKEN_FACTORY}",
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
