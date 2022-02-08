#!/bin/bash

set -eo pipefail

function verify-contract() {
    set +e
    echo "dapp verify-contract $1 $2 ${@:3}" >&2
    local result=$(dapp verify-contract "$1" "$2" ${@:3})
    local result_status=$?

    while [[ "$result" =~ "Pending in queue" ]]; do
        sleep 5
        echo $result >&2
        echo "dapp verify-contract $1 $2 ${@:3}" >&2
        result=$(dapp verify-contract "$1" "$2" ${@:3})
    done
    result_status=$?

    local exit_code=$result_status

    echo $result >&2
    if [[ $result_status -ne 0 ]]; then
        if [[ "$result" =~ "Already Verified" || "$result" =~ "already verified" ]]; then
            exit_code=0
        else
            exit_code=1
        fi
    fi
    return $exit_code
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

    ZERO_ADDRESS='0x0000000000000000000000000000000000000000'
    set -u
    verify-contract "src/utils/ForwardProxy.sol:ForwardProxy" "$RWA007_A_OPERATOR" "$ZERO_ADDRESS"
    verify-contract "src/utils/ForwardProxy.sol:ForwardProxy" "$RWA007_A_MATE" "$ZERO_ADDRESS"
    verify-contract "src/tokens/mocks/MockOFH.sol:MockOFH" "$RWA_OFH_TOKEN" "$RWA_OFH_TOKEN_SUPPLY"
    verify-contract "src/tokens/TokenWrapper.sol:TokenWrapper" "$RWA007" "$RWA_OFH_TOKEN"
    verify-contract "src/RwaOutputConduit2.sol:RwaOutputConduit2" "$RWA007_A_OUTPUT_CONDUIT" "$MCD_DAI"
    verify-contract "src/RwaInputConduit2.sol:RwaInputConduit2" "$RWA007_A_INPUT_CONDUIT" "$MCD_DAI" "$RWA007_A_URN"
    verify-contract "src/RwaUrn2.sol:RwaUrn2" "$RWA007_A_URN" "$MCD_VAT" "$MCD_JUG" "$MCD_JOIN_RWA007_A" "$MCD_JOIN_DAI" "$RWA007_A_OUTPUT_CONDUIT" "$RWA_URN_2_GEM_CAP"
    verify-contract "src/RwaLiquidationOracle2.sol:RwaLiquidationOracle2" "$MIP21_LIQUIDATION_ORACLE_2" "$MCD_VAT" "$MCD_VOW"
    set +u
fi
