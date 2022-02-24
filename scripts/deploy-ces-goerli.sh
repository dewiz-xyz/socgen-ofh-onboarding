#!/bin/bash
set -eo pipefail

source "${BASH_SOURCE%/*}/common.sh"

[[ "$ETH_RPC_URL" && "$(seth chain)" == "goerli" ]] || die "Please set a goerli ETH_RPC_URL"
[[ "$RWA_URN_2_GEM_CAP" ]] || die "Please set RWA_URN_2_GEM_CAP"

# shellcheck disable=SC1091
source "${BASH_SOURCE%/*}/build-env-addresses.sh" ces-goerli >/dev/null 2>&1

export ETH_GAS=6000000

# TODO: confirm if name/symbol is going to follow the RWA convention
# TODO: confirm with DAO at the time of mainnet deployment if OFH will indeed be 007
[[ -z "$NAME" ]] && NAME="RWA-007-AT1"
[[ -z "$SYMBOL" ]] && SYMBOL="RWA007AT1"
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

# [[ -z "$MIP21_LIQUIDATION_ORACLE_2" ]] && MIP21_LIQUIDATION_ORACLE_2="0xDEADBEEFDEADBEEFDEADBEEFDEADBEEFDEADBEEF"
# TODO: confirm liquidations handling - no liquidations for the time being

ZERO_ADDRESS="0x0000000000000000000000000000000000000000"

# goerli only, trust a couple of addresses
TRUST1="0x597084d145e96Ae2e89E1c9d8DEE6d43d3557898"
TRUST2="0xCB84430E410Df2dbDE0dF04Cf7711E656C90BDa2"

ILK="${SYMBOL}-${LETTER}"
echo "ILK: ${ILK}" >&2
ILK_ENCODED=$(seth --to-bytes32 "$(seth --from-ascii "$ILK")")

# build it
make build

[[ -z "$OPERATOR" ]] && OPERATOR=$(dapp create ForwardProxy "$ZERO_ADDRESS") # using generic forward proxy for goerli
echo "${SYMBOL}_${LETTER}_OPERATOR: ${OPERATOR}" >&2

[[ -z "$MATE" ]] && MATE=$(dapp create ForwardProxy "$ZERO_ADDRESS") # using generic forward proxy for goerli
echo "${SYMBOL}_${LETTER}_MATE: ${MATE}" >&2

[[ -z "$RWA_OFH_TOKEN" ]] && {
    [[ -z "$RWA_OFH_TOKEN_SUPPLY" ]] && RWA_OFH_TOKEN_SUPPLY=400
    RWA_OFH_TOKEN=$(dapp create MockOFH "$RWA_OFH_TOKEN_SUPPLY")
    # Transfers the total supply to the operator's account
    seth send "$RWA_OFH_TOKEN" 'transfer(address,uint256)' "$OPERATOR" "$RWA_OFH_TOKEN_SUPPLY"
}

# tokenize it
[[ -z "$RWA_WRAPPER_TOKEN" ]] && RWA_WRAPPER_TOKEN=$(dapp create TokenWrapper "$RWA_OFH_TOKEN")
echo "${SYMBOL}: ${RWA_WRAPPER_TOKEN}" >&2

# route it
[[ -z "$RWA_OUTPUT_CONDUIT_2" ]] && {
    RWA_OUTPUT_CONDUIT_2=$(dapp create RwaOutputConduit2 "$MCD_DAI")
    echo "${SYMBOL}_${LETTER}_OUTPUT_CONDUIT: ${RWA_OUTPUT_CONDUIT_2}" >&2

    # trust addresses for goerli
    seth send "$RWA_OUTPUT_CONDUIT_2" 'hope(address)' "$OPERATOR" &&
        seth send "$RWA_OUTPUT_CONDUIT_2" 'mate(address)' "$MATE" &&
        seth send "$RWA_OUTPUT_CONDUIT_2" 'rely(address)' "$MCD_PAUSE_PROXY" &&
        seth send "$RWA_OUTPUT_CONDUIT_2" 'deny(address)' "$ETH_FROM"

} || {
    echo "${SYMBOL}_${LETTER}_OUTPUT_CONDUIT: ${RWA_OUTPUT_CONDUIT_2}" >&2
}

# join it
RWA_JOIN=$(dapp create AuthGemJoin "$MCD_VAT" "$ILK_ENCODED" "$RWA_WRAPPER_TOKEN")
echo "MCD_JOIN_${SYMBOL}_${LETTER}: ${RWA_JOIN}" >&2
seth send "$RWA_JOIN" 'rely(address)' "$MCD_PAUSE_PROXY"

# urn it
RWA_URN_2=$(dapp create RwaUrn2 "$MCD_VAT" "$MCD_JUG" "$RWA_JOIN" "$MCD_JOIN_DAI" "$RWA_OUTPUT_CONDUIT_2" $RWA_URN_2_GEM_CAP)
echo "${SYMBOL}_${LETTER}_URN: ${RWA_URN}" >&2

seth send "$RWA_URN_2" 'rely(address)' "$MCD_PAUSE_PROXY" &&
    seth send "$RWA_URN_2" 'deny(address)' "$ETH_FROM" &&
    # rely it
    seth send "$RWA_JOIN" 'rely(address)' "$RWA_URN_2" &&
    # deny it
    seth send "$RWA_JOIN" 'deny(address)' "$ETH_FROM"

# connect it
[[ -z "$RWA_INPUT_CONDUIT_2" ]] && {
    RWA_INPUT_CONDUIT_2=$(dapp create RwaInputConduit2 "$MCD_DAI" "$RWA_URN_2")
    echo "${SYMBOL}_${LETTER}_INPUT_CONDUIT: ${RWA_INPUT_CONDUIT_2}" >&2

    # trust addresses for goerli
    seth send "$RWA_INPUT_CONDUIT_2" 'mate(address)' "$MATE" &&
        seth send "$RWA_INPUT_CONDUIT_2" 'rely(address)' "$MCD_PAUSE_PROXY" &&
        seth send "$RWA_INPUT_CONDUIT_2" 'deny(address)' "$ETH_FROM"
} || {
    echo "${SYMBOL}_${LETTER}_INPUT_CONDUIT: ${RWA_INPUT_CONDUIT_2}" >&2
}

# price it
[[ -z "$MIP21_LIQUIDATION_ORACLE_2" ]] && {
    MIP21_LIQUIDATION_ORACLE_2=$(dapp create RwaLiquidationOracle2 "$MCD_VAT" "$MCD_VOW")
    echo "MIP21_LIQUIDATION_ORACLE_2: ${MIP21_LIQUIDATION_ORACLE_2}" >&2

    seth send "$MIP21_LIQUIDATION_ORACLE_2" 'rely(address)' "$MCD_PAUSE_PROXY" &&
        seth send "$MIP21_LIQUIDATION_ORACLE_2" 'deny(address)' "$ETH_FROM"
} || {
    echo "MIP21_LIQUIDATION_ORACLE_2: ${MIP21_LIQUIDATION_ORACLE_2}" >&2
}

cat <<JSON
{
    "ILK": "${ILK}",
    "MIP21_LIQUIDATION_ORACLE_2": "${MIP21_LIQUIDATION_ORACLE_2}",
    "RWA_OFH_TOKEN": "${RWA_OFH_TOKEN}",
    "${SYMBOL}": "${RWA_WRAPPER_TOKEN}",
    "MCD_JOIN_${SYMBOL}_${LETTER}": "${RWA_JOIN}",
    "${SYMBOL}_${LETTER}_URN": "${RWA_URN_2}",
    "${SYMBOL}_${LETTER}_INPUT_CONDUIT": "${RWA_INPUT_CONDUIT_2}",
    "${SYMBOL}_${LETTER}_OUTPUT_CONDUIT": "${RWA_OUTPUT_CONDUIT_2}",
    "${SYMBOL}_${LETTER}_OPERATOR": "${OPERATOR}",
    "${SYMBOL}_${LETTER}_MATE": "${MATE}"
}
JSON
