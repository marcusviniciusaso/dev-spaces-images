# .bashrc

# Source global definitions
if [ -f /etc/bashrc ]; then
        . /etc/bashrc
fi

# User specific environment
if ! [[ "$PATH" =~ "$HOME/.local/bin:$HOME/bin:" ]]
then
    PATH="$HOME/.local/bin:$HOME/bin:$PATH"
fi
export PATH

# Keep Podman/runtime state in persistent writable directories when DevSpaces runs with random UID.
export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-/home/user/.config}"
export XDG_DATA_HOME="${XDG_DATA_HOME:-/home/user/.local/share}"
export XDG_CACHE_HOME="${XDG_CACHE_HOME:-/home/user/.cache}"

if [ -z "${XDG_RUNTIME_DIR:-}" ]; then
                export XDG_RUNTIME_DIR="/tmp/runtime-$(id -u)"
fi

mkdir -p "$XDG_RUNTIME_DIR" "$XDG_CONFIG_HOME" "$XDG_DATA_HOME" "$XDG_CACHE_HOME"
chmod 700 "$XDG_RUNTIME_DIR" 2>/dev/null || true

# Fix ownership for Podman rootless when OpenShift assigns arbitrary UID
_CURRENT_UID=$(id -u)
for _xdg_dir in "$XDG_CONFIG_HOME" "$XDG_DATA_HOME" "$XDG_CACHE_HOME"; do
    if [ -d "$_xdg_dir" ] && [ "$(stat -c '%u' "$_xdg_dir" 2>/dev/null)" != "$_CURRENT_UID" ]; then
        chown -R "$_CURRENT_UID:0" "$_xdg_dir" 2>/dev/null || true
    fi
done
unset _CURRENT_UID _xdg_dir

# Rootless Podman in DevSpaces often cannot mount overlay; use vfs in persistent user storage.
export CONTAINERS_STORAGE_CONF="${CONTAINERS_STORAGE_CONF:-$XDG_CONFIG_HOME/containers/storage.conf}"
PODMAN_RUNROOT="/tmp/containers-$(id -u)/runroot"
PODMAN_GRAPHROOT="$XDG_DATA_HOME/containers-vfs/storage"

mkdir -p "$XDG_CONFIG_HOME/containers" "$PODMAN_RUNROOT" "$PODMAN_GRAPHROOT"

cat > "$CONTAINERS_STORAGE_CONF" <<EOF
# managed-by=devspaces-python-image
[storage]
driver = "vfs"
runroot = "$PODMAN_RUNROOT"
graphroot = "$PODMAN_GRAPHROOT"

[storage.options]
additionalimagestores = []
EOF

# Uncomment the following line if you don't like systemctl's auto-paging feature:
# export SYSTEMD_PAGER=

# User specific aliases and functions
if [ -d ~/.bashrc.d ]; then
        for rc in ~/.bashrc.d/*; do
                if [ -f "$rc" ]; then
                        . "$rc"
                fi
        done
fi

unset rc

# Load bash aliases
if [ -f ~/.bash_aliases ]; then
    . ~/.bash_aliases
fi