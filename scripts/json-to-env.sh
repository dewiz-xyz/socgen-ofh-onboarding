#!/usr/bin/env bash

json-to-env() {
	local file=$1
	local output=$(
		jq -r 'to_entries | map(.key + "|" + (.value | tostring)) | .[]' "$file" |
			while IFS='|' read -r key value; do
				# If it's an address, make sure it's checksummed
				if [[ "$value" =~ '^0x[0-9a-fA-F]{40}$' ]]; then
					PAIR="${key}=$(seth --to-checksum-address "${value}")"
				else
					PAIR="${key}=${value}"
				fi
				echo "${PAIR}"
			done
	)

	for pair in $output; do
		echo "export ${pair}"
	done
}

# Executes the function if it's been called as a script.
# This will evaluate to false if this script is sourced by other script.
if [ "$0" = "$BASH_SOURCE" ]; then
	json-to-env $@
fi
