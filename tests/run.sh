#!/bin/sh
# run.sh BIN: round-trip every tests/*.bin with default and a smaller low-nibble context
set -eu
BIN=$1
T=$(mktemp -d)
trap 'rm -rf "$T"' EXIT
for f in "$(dirname "$0")"/*.bin; do
	for k in "" "-l 4"; do
		# shellcheck disable=SC2086
		"$BIN" c $k "$f" "$T/c"
		"$BIN" d "$T/c" "$T/d"
		cmp "$f" "$T/d"
		printf '%-12s %-6s %7d -> %7d\n' "$(basename "$f")" "${k:-auto}" "$(wc -c < "$f")" "$(wc -c < "$T/c")"
	done
done
echo ok
