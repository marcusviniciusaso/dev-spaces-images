# .bashrc

# Source global definitions
if [ -f /etc/bashrc ]; then
        . /etc/bashrc
fi

if ! declare -F use-java >/dev/null 2>&1 && [ -f /etc/profile.d/05-java-versions.sh ]; then
    . /etc/profile.d/05-java-versions.sh
fi

if [ -d "${HOME:-}" ] && [ ! -w "$HOME" ]; then
        if [ -d "/home/user/persistent" ] && [ -w "/home/user/persistent" ]; then
                export HOME="/home/user/persistent/home-$(id -u)"
        else
                export HOME="/tmp/home-$(id -u)"
        fi
        mkdir -p "$HOME"
        for _f in .bashrc .bash_aliases; do
                [ -f "$HOME/$_f" ] || cp -p "/home/tooling/$_f" "$HOME/$_f" 2>/dev/null || true
        done
        unset _f
fi

# User specific environment
if ! [[ "$PATH" =~ "$HOME/.local/bin:$HOME/bin:" ]]
then
    PATH="$HOME/.local/bin:$HOME/bin:$PATH"
fi
export PATH

# Keep Podman/runtime state writable when DevSpaces runs with random UID.
# Non-writable paths fall back to persistent user storage, /tmp as last resort.
DEFAULT_XDG_CONFIG_HOME="${HOME}/.config"
DEFAULT_XDG_DATA_HOME="${HOME}/.local/share"
DEFAULT_XDG_CACHE_HOME="${HOME}/.cache"

if [ -d "/home/user/persistent" ] && [ -w "/home/user/persistent" ]; then
        XDG_FALLBACK_BASE="/home/user/persistent/.xdg-$(id -u)"
else
        XDG_FALLBACK_BASE="/tmp/xdg-$(id -u)"
fi

if [ -n "${XDG_CONFIG_HOME:-}" ]; then
        CANDIDATE_XDG_CONFIG_HOME="$XDG_CONFIG_HOME"
else
        CANDIDATE_XDG_CONFIG_HOME="$DEFAULT_XDG_CONFIG_HOME"
fi

if [ -d "$CANDIDATE_XDG_CONFIG_HOME" ] && [ ! -w "$CANDIDATE_XDG_CONFIG_HOME" ]; then
        export XDG_CONFIG_HOME="$XDG_FALLBACK_BASE/config"
else
        export XDG_CONFIG_HOME="$CANDIDATE_XDG_CONFIG_HOME"
fi

if [ -n "${XDG_DATA_HOME:-}" ]; then
        CANDIDATE_XDG_DATA_HOME="$XDG_DATA_HOME"
else
        CANDIDATE_XDG_DATA_HOME="$DEFAULT_XDG_DATA_HOME"
fi

if [ -d "$CANDIDATE_XDG_DATA_HOME" ] && [ ! -w "$CANDIDATE_XDG_DATA_HOME" ]; then
        export XDG_DATA_HOME="$XDG_FALLBACK_BASE/data"
else
        export XDG_DATA_HOME="$CANDIDATE_XDG_DATA_HOME"
fi

if [ -n "${XDG_CACHE_HOME:-}" ]; then
        CANDIDATE_XDG_CACHE_HOME="$XDG_CACHE_HOME"
else
        CANDIDATE_XDG_CACHE_HOME="$DEFAULT_XDG_CACHE_HOME"
fi

if [ -d "$CANDIDATE_XDG_CACHE_HOME" ] && [ ! -w "$CANDIDATE_XDG_CACHE_HOME" ]; then
        export XDG_CACHE_HOME="$XDG_FALLBACK_BASE/cache"
else
        export XDG_CACHE_HOME="$CANDIDATE_XDG_CACHE_HOME"
fi

if [ -z "${XDG_RUNTIME_DIR:-}" ]; then
        export XDG_RUNTIME_DIR="/tmp/runtime-$(id -u)"
fi

mkdir -p "$XDG_RUNTIME_DIR" "$XDG_CONFIG_HOME" "$XDG_DATA_HOME" "$XDG_CACHE_HOME"
chmod 700 "$XDG_RUNTIME_DIR" 2>/dev/null || true

# Rootless Podman in DevSpaces often cannot mount overlay; use vfs in persistent user storage.
# Priorizar CONTAINERS_STORAGE se definido no devfile, senão usar XDG_DATA_HOME
if [ -n "${CONTAINERS_STORAGE:-}" ]; then
	PODMAN_GRAPHROOT="${CONTAINERS_STORAGE}"
	export CONTAINERS_STORAGE_CONF="${CONTAINERS_STORAGE_CONF:-${CONTAINERS_STORAGE}/.containers-storage.conf}"
else
	PODMAN_GRAPHROOT="$XDG_DATA_HOME/containers-vfs/storage"
	export CONTAINERS_STORAGE_CONF="${CONTAINERS_STORAGE_CONF:-$XDG_CONFIG_HOME/containers/storage.conf}"
fi

PODMAN_RUNROOT="/tmp/containers-$(id -u)/runroot"
mkdir -p "$XDG_CONFIG_HOME/containers" "$PODMAN_RUNROOT" "$PODMAN_GRAPHROOT"

# Persist podman login credentials (JFrog Artifactory) across pause/resume
if [ -n "${CONTAINERS_STORAGE:-}" ]; then
	export REGISTRY_AUTH_FILE="${REGISTRY_AUTH_FILE:-$(dirname "$CONTAINERS_STORAGE")/.containers/auth.json}"
else
	export REGISTRY_AUTH_FILE="${REGISTRY_AUTH_FILE:-$XDG_CONFIG_HOME/containers/auth.json}"
fi
mkdir -p "$(dirname "$REGISTRY_AUTH_FILE")"

cat > "$CONTAINERS_STORAGE_CONF" <<EOF
# managed-by=devspaces-qa-image
[storage]
driver = "vfs"
runroot = "$PODMAN_RUNROOT"
graphroot = "$PODMAN_GRAPHROOT"

[storage.options]
additionalimagestores = []
EOF

# Exportar CONTAINERS_STORAGE para garantir que o Podman use o caminho correto
if [ -n "${CONTAINERS_STORAGE:-}" ]; then
	export CONTAINERS_STORAGE
fi

# Keep engine/runtime defaults local to user-owned config to avoid fallback to /home/user/.config.
export CONTAINERS_CONF="${CONTAINERS_CONF:-$XDG_CONFIG_HOME/containers/containers.conf}"
RUNTIME_BIN="$(command -v crun 2>/dev/null || command -v runc 2>/dev/null || true)"
if [ -n "$RUNTIME_BIN" ]; then
cat > "$CONTAINERS_CONF" <<EOF
# managed-by=devspaces-qa-image
[engine]
runtime = "$RUNTIME_BIN"
cgroup_manager = "cgroupfs"
events_logger = "file"
EOF
fi

# Default isolation that proved stable in nested/rootless DevSpaces builds.
export BUILDAH_ISOLATION="${BUILDAH_ISOLATION:-oci}"

# Point Maven and Gradle to persistent storage to survive pause/resume cycles
if [ -d /home/user/persistent ] && [ -w /home/user/persistent ]; then
    export MAVEN_USER_HOME="${MAVEN_USER_HOME:-/home/user/persistent}"
    export GRADLE_USER_HOME="${GRADLE_USER_HOME:-/home/user/persistent/.gradle}"
fi

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

# Load bash aliases with fallback paths for DevSpaces environments with dynamic HOME
if [ -f ~/.bash_aliases ]; then
    . ~/.bash_aliases
elif [ -f /home/tooling/.bash_aliases ]; then
    . /home/tooling/.bash_aliases
elif [ -f /home/user/.bash_aliases ]; then
    . /home/user/.bash_aliases
fi

# Ensure devspaces helper commands exist even if alias files were not loaded.
if ! declare -F devspaces-environment >/dev/null 2>&1; then
        devspaces-environment() {
                bash /home/tooling/devspaces-environment.sh
        }
fi

if ! declare -F devspaces-setup >/dev/null 2>&1; then
        devspaces-setup() {
                bash /home/tooling/devspaces-setup.sh
        }
fi

if ! declare -F devspaces-linux-release >/dev/null 2>&1; then
        devspaces-linux-release() {
                cat /etc/devspaces-linux-release
        }
fi

# Prompt fallback for interactive shells in case aliases were not loaded.
case "$-" in
	*i*)
		if ! declare -F parse_git_branch >/dev/null 2>&1; then
			parse_git_branch() {
				git branch 2> /dev/null | sed -e '/^[^*]/d' -e 's/* \(.*\)/(\1)/'
			}
		fi
		export PS1="\[\e[34m\]${DEVWORKSPACE_NAME:-\u@\h} \[\e[32m\]\w \[\e[91m\]\$(git branch 2>/dev/null | sed -n 's/* \(.*\)/(\1)/p')\[\e[00m\]\$ "
		;;
esac

