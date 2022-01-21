#!/usr/bin/env bash

set -eo pipefail

source "${BASH_SOURCE%/*}/common.sh"

estimate_gas $@
