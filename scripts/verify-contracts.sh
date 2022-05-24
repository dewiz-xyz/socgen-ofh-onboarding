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


# TODO: fix this!!!
# Executes the function if it's been called as a script.
# This will evaluate to false if this script is sourced by other script.
if [ "$0" = "$BASH_SOURCE" ]; then
    # shellcheck disable=SC1091
    source "${BASH_SOURCE%/*}/build-env-addresses.sh" "$1" >/dev/null 2>&1

    chain=$([[ "$1" =~ "goerli" ]] && echo 'goerli' || echo 'mainnet')
    [ -z "$ETH_RPC_URL" ] && ETH_RPC_URL="$(alchemy-url $chain)"

    exit_code=0

    set -u

    verify-contract "lib/forward-proxy/src/ForwardProxy.sol:ForwardProxy" "$RWA008AT5_A_OPERATOR" || exit_code=1
    verify-contract "lib/forward-proxy/src/ForwardProxy.sol:ForwardProxy" "$RWA008AT5_A_MATE" || exit_code=1
    verify-contract "lib/mip21-toolkit/src/tokens/RwaToken.sol:RwaToken" "$RWA008AT5" "\"$SYMBOL\"" "\"$NAME\"" || exit_code=1
    verify-contract "lib/mip21-toolkit/src/conduits/RwaOutputConduit2.sol:RwaOutputConduit2" "$RWA008AT5_A_OUTPUT_CONDUIT" "$MCD_DAI" || exit_code=1
    verify-contract "lib/mip21-toolkit/src/conduits/RwaInputConduit2.sol:RwaInputConduit2" "$RWA008AT5_A_INPUT_CONDUIT" "$MCD_DAI" "$RWA008AT5_A_URN" || exit_code=1
    verify-contract "lib/mip21-toolkit/src/urns/RwaUrn.sol:RwaUrn" "$RWA008AT5_A_URN" "$MCD_VAT" "$MCD_JUG" "$MCD_JOIN_RWA008AT4_A" "$MCD_JOIN_DAI" "$RWA008AT5_A_OUTPUT_CONDUIT" || exit_code=1
    verify-contract "lib/mip21-toolkit/src/oracles/RwaLiquidationOracle.sol:RwaLiquidationOracle" "$MIP21_LIQUIDATION_ORACLE" "$MCD_VAT" "$MCD_VOW" || exit_code=1
    verify-contract "src/RwaUrnProxyActions.sol:RwaUrnProxyActions" "$RWA_URN_PROXY_ACTIONS" || exit_code=1

    set +u

    exit $exit_code
fi
