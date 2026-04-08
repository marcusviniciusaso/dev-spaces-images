#!/bin/bash
# Colored bash prompt for Ansible Dev Spaces.
# Installed to /etc/profile.d/ for interactive login shells.

[[ $- != *i* ]] && return

if [[ -n "${NO_COLOR:-}" && -z "${BASH_PROMPT_USE_COLOR:-}" ]]; then
  return
fi

case "${TERM:-}" in
  *color* | xterm* | screen* | tmux* | linux) ;;
  *)
    [[ -z "${COLORTERM:-}" ]] && return
    ;;
esac

_adt_git_branch() {
  local branch
  branch=$(git symbolic-ref --short HEAD 2>/dev/null) || \
    branch=$(git rev-parse --short HEAD 2>/dev/null)
  [[ -z "$branch" ]] && return

  local dirty
  dirty=$(git status --porcelain --untracked-files=no --ignore-submodules=dirty 2>/dev/null | head -n1)
  if [[ -n "$dirty" ]]; then
    printf ' \001\e[33m\002(%s*)\001\e[0m\002' "$branch"
  else
    printf ' \001\e[32m\002(%s)\001\e[0m\002' "$branch"
  fi
}

_adt_build_prompt() {
  local last_exit=$?
  local red='\[\e[31m\]'
  local green='\[\e[32m\]'
  local blue='\[\e[34m\]'
  local bold='\[\e[1m\]'
  local reset='\[\e[0m\]'

  local prefix=""
  if [[ -n "${container:-}" ]]; then
    prefix="⬢ "
  fi

  local status_indicator=""
  if [[ $last_exit -ne 0 ]]; then
    status_indicator="${red}[${last_exit}]${reset} "
  fi

  PS1="${status_indicator}${prefix}${bold}${green}\u@ansible-devspaces${reset}:${bold}${blue}\w${reset}\$(_adt_git_branch)\$ "
}

if [[ -n "${PROMPT_COMMAND:-}" ]]; then
  PROMPT_COMMAND="_adt_build_prompt;${PROMPT_COMMAND}"
else
  PROMPT_COMMAND="_adt_build_prompt"
fi
