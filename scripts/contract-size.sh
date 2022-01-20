#!/usr/bin/env bash

set -eo pipefail

source "${BASH_SOURCE%/*}/common.sh"

contract_size $@
