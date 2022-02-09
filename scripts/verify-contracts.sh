#!/bin/bash

set -eo pipefail

function verify-contract() {
    set +e
    log-call "dapp verify-contract $1 $2 ${@:3}"

    local result
    local result_err
    { result_err=$(dapp verify-contract "$1" "$2" ${@:3} 2>&1 1>&${result}); } {result}>&1
    local result_status=$?

    while [[ "$result_err" =~ "Pending in queue" ]]; do
        sleep 5
        log-response "$result_err"
        log-call "dapp verify-contract $1 $2 ${@:3}"

        { result_err=$(dapp verify-contract "$1" "$2" ${@:3} 2>&1 1>&${result}); } {result}>&1
        result_status=$?
    done

    log-response "$result_err"

    local return_code=$result_status
    if [[ $result_status -ne 0 ]]; then
        if [[ "$result_err" =~ "Already Verified" || "$result_err" =~ "already verified" ]]; then
            return_code=0
        else
            return_code=1
        fi
    fi
    return $return_code
}

function log-call() {
    echo -e "$ $@" >&2
}

function log-response() {
    echo -e "$@" | sed -e 's/^/> /' >&2
}

function alchemy-url() {
    echo "https://eth-$1.alchemyapi.io/v2/${ALCHEMY_API_KEY}"
}

# Executes the function if it's been called as a script.
# This will evaluate to false if this script is sourced by other script.
if [ "$0" = "$BASH_SOURCE" ]; then
    # shellcheck disable=SC1091
    source "${BASH_SOURCE%/*}/build-env-addresses.sh" "$1" >/dev/null 2>&1

    chain=$([[ "$1" =~ "goerli" ]] && echo 'goerli' || echo 'mainnet')
    # echo ">>>>> ${chain}" >&2
    [ -z "$ETH_RPC_URL" ] && ETH_RPC_URL="$(alchemy-url $chain)"

    exit_code=0
    ZERO_ADDRESS='0x0000000000000000000000000000000000000000'

    set -u

    verify-contract "src/utils/ForwardProxy.sol:ForwardProxy" "$RWA007_A_OPERATOR" "$ZERO_ADDRESS" || exit_code=1
    verify-contract "src/utils/ForwardProxy.sol:ForwardProxy" "$RWA007_A_MATE" "$ZERO_ADDRESS" || exit_code=1
    verify-contract "src/tokens/mocks/MockOFH.sol:MockOFH" "$RWA_OFH_TOKEN" "$RWA_OFH_TOKEN_SUPPLY" || exit_code=1
    verify-contract "src/tokens/TokenWrapper.sol:TokenWrapper" "$RWA007" "$RWA_OFH_TOKEN" || exit_code=1
    verify-contract "src/RwaOutputConduit2.sol:RwaOutputConduit2" "$RWA007_A_OUTPUT_CONDUIT" "$MCD_DAI" || exit_code=1
    verify-contract "src/RwaInputConduit2.sol:RwaInputConduit2" "$RWA007_A_INPUT_CONDUIT" "$MCD_DAI" "$RWA007_A_URN" || exit_code=1
    verify-contract "src/RwaUrn2.sol:RwaUrn2" "$RWA007_A_URN" "$MCD_VAT" "$MCD_JUG" "$MCD_JOIN_RWA007_A" "$MCD_JOIN_DAI" "$RWA007_A_OUTPUT_CONDUIT" "$RWA_URN_2_GEM_CAP" || exit_code=1
    verify-contract "src/RwaLiquidationOracle2.sol:RwaLiquidationOracle2" "$MIP21_LIQUIDATION_ORACLE_2" "$MCD_VAT" "$MCD_VOW" || exit_code=1

    set +u

    exit $exit_code
fi
