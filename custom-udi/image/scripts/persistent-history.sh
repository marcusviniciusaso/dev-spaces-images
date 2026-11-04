# Persiste o historico do bash
[ -n "${BASH_VERSION:-}" ] || return 0
case "$-" in *i*) ;; *) return 0 ;; esac

if mountpoint -q /home/user 2>/dev/null; then
    HISTFILE=/home/user/.bash_history
elif [ -d /home/user/persistent ] && [ -w /home/user/persistent ]; then
    HISTFILE=/home/user/persistent/.bash_history
elif [ -w "${PROJECTS_ROOT:-/projects}" ]; then
    HISTFILE="${PROJECTS_ROOT:-/projects}/.bash_history"
fi
HISTSIZE=10000
HISTFILESIZE=20000
HISTCONTROL=ignoreboth
shopt -s histappend

case "${PROMPT_COMMAND:-}" in
    *"history -a"*) ;;
    *) PROMPT_COMMAND="history -a${PROMPT_COMMAND:+; $PROMPT_COMMAND}" ;;
esac
