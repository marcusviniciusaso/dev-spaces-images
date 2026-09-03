#!/usr/bin/env bash

set -euo pipefail

. /usr/local/bin/fnm-common.sh

ensure_node_state
apply_node_target "$(read_node_target)" >/dev/null 2>&1 || true

echo ""
echo "Versões de Node disponíveis:"
echo ""
current_target="$(read_node_target)"
for target in 22 24 25; do
	version="$(node_target_to_version "$target")"
	node_bin_dir="$(node_bin_dir_for_target "$target")"
	if [ -x "$node_bin_dir/node" ]; then
		if [ "$target" = "$current_target" ]; then
			echo "* $target ($version)"
		else
			echo "  $target ($version)"
		fi
	fi
done
echo ""
echo "Ativa: $(node -v)"
echo "npm : $(npm -v)"
echo ""
