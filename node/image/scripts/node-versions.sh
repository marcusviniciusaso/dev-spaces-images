#!/usr/bin/env bash

set -euo pipefail

if [ "$#" -eq 0 ]; then
	exec /usr/local/bin/nodelist
fi

exec /usr/local/bin/nodeuse "$@"
