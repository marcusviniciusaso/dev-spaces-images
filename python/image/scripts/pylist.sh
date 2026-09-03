#!/usr/bin/env bash

set -euo pipefail

. /usr/local/bin/py-common.sh

ensure_python_state
apply_python_target "$(read_python_target)" >/dev/null 2>&1 || true

echo ""
echo "Versões de Python disponíveis:"
echo ""
current_target="$(read_python_target)"
for target in $(python_installed_targets); do
	version="$(python_target_to_version "$target")"
	python_bin_dir="$(python_bin_dir_for_target "$target")"
	if [ -x "$python_bin_dir/python3" ]; then
		if [ "$target" = "$current_target" ]; then
			echo "* $target ($version)"
		else
			echo "  $target ($version)"
		fi
	fi
done
echo ""
echo "Ativa: $(python3 -V 2>&1)"
echo "pip  : $(pip3 -V 2>/dev/null | awk '{print $2}')"
echo ""
