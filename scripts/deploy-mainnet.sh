#!/bin/bash
#
# bash scripts/deploy-mainnet.sh

set -eo pipefail

source "${BASH_SOURCE%/*}/common.sh"

[[ "$ETH_RPC_URL" && "$(seth chain)" == "ethlive" ]] || die "Please set a mainnet ETH_RPC_URL"


# shellcheck disable=SC1091
source "${BASH_SOURCE%/*}/build-env-addresses.sh" mainnet >/dev/null 2>&1

# TODO: confirm for mainnet deployment
export ETH_GAS=6000000

# TODO: confirm if name/symbol is going to follow the RWA convention
# TODO: confirm with DAO at the time of mainnet deployment if OFH will indeed be 007
[[ -z "$NAME" ]] && NAME="RWA-007";
[[ -z "$SYMBOL" ]] && SYMBOL="RWA007";
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
[[ -z "$LETTER" ]] && LETTER="A";
[[ -z "$OPERATOR" ]] && OPERATOR="0xA5Eee849FF395f9FA592645979f2A8Af6E0eF5c3" # TODO: update for mainnet

ILK="${SYMBOL}-${LETTER}"
ILK_ENCODED=$(seth --to-bytes32 "$(seth --from-ascii ${ILK})")

# build it
dapp --use solc:0.6.12 build

# tokenize it
RWA_TOKEN=$(dapp create "src/TokenWrapper.sol:TokenWrapper")
seth send "${RWA_TOKEN}" 'transfer(address,uint256)' "$OPERATOR" "$(seth --to-wei 1.0 ether)"

# route it
[[ -z "$RWA_OUTPUT_CONDUIT" ]] && RWA_OUTPUT_CONDUIT=$(dapp create RwaConduits:RwaOutputConduit "${MCD_DAI}")

if [ "$RWA_OUTPUT_CONDUIT" != "$OPERATOR" ]; then
    seth send "${RWA_OUTPUT_CONDUIT}" 'rely(address)' "${MCD_PAUSE_PROXY}"
    if [ "$1" == "goerli" ]; then
        seth send "${RWA_OUTPUT_CONDUIT}" 'kiss(address)' "${TRUST1}"
        seth send "${RWA_OUTPUT_CONDUIT}" 'kiss(address)' "${TRUST2}"
    fi
    seth send "${RWA_OUTPUT_CONDUIT}" 'deny(address)' "${ETH_FROM}"
fi

# join it
RWA_JOIN=$(dapp create AuthGemJoin "${MCD_VAT}" "${ILK_ENCODED}" "${RWA_TOKEN}")
seth send "${RWA_JOIN}" 'rely(address)' "${MCD_PAUSE_PROXY}"

# urn it
RWA_URN=$(dapp create RwaUrn "${MCD_VAT}" "${MCD_JUG}" "${RWA_JOIN}" "${MCD_JOIN_DAI}" "${RWA_OUTPUT_CONDUIT}")
seth send "${RWA_URN}" 'rely(address)' "${MCD_PAUSE_PROXY}"
seth send "${RWA_URN}" 'deny(address)' "${ETH_FROM}"

# rely it
seth send "${RWA_JOIN}" 'rely(address)' "${RWA_URN}"

# deny it
seth send "${RWA_JOIN}" 'deny(address)' "${ETH_FROM}"

# connect it
[[ -z "$RWA_INPUT_CONDUIT" ]] && RWA_INPUT_CONDUIT=$(dapp create RwaConduits:RwaInputConduit "${MCD_DAI}" "${RWA_URN}")

# print it
echo "OPERATOR: ${OPERATOR}"
echo "ILK: ${ILK}"
echo "${SYMBOL}: ${RWA_TOKEN}"
echo "MCD_JOIN_${SYMBOL}_${LETTER}: ${RWA_JOIN}"
echo "${SYMBOL}_${LETTER}_URN: ${RWA_URN}"
echo "${SYMBOL}_${LETTER}_INPUT_CONDUIT: ${RWA_INPUT_CONDUIT}"
echo "${SYMBOL}_${LETTER}_OUTPUT_CONDUIT: ${RWA_OUTPUT_CONDUIT}"