#!/usr/bin/env bash

replace-spell-addresses() {
	local deployed_addresses=$1
	local spell_file=$2
	local spell_helper_addresses_file=$3
	jq -r 'to_entries | map(.key + "|" + (.value | tostring)) | .[]' "$deployed_addresses" |
		while IFS='|' read -r key value; do
			value="$(seth --to-checksum-address "${value}")"
			# Replace occurrences in the spell file
			sed -r -e "/^\\s*address.*\\b${key}\\b\\s*=/s/(=\s*)0x[^;]*/\\1${value}/" -i "$spell_file"
			# Replace occurrences in the test helper file
			sed -r -e "/^\\s*addr\\[\\\"${key}\\\"\\]\\s*=/s/(=\s*)0x[^;]*/\\1${value}/" -i "$spell_helper_addresses_file"
		done
}

# Executes the function if it's been called as a script.
# This will evaluate to false if this script is sourced by other script.
if [ "$0" = "$BASH_SOURCE" ]; then
	replace-spell-addresses $@
fi

