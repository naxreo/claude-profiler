# bash completion for claude-profiler

_claude_profiler_completions() {
  local cur prev words cword
  COMPREPLY=()
  cur="${COMP_WORDS[COMP_CWORD]}"
  prev="${COMP_WORDS[COMP_CWORD-1]}"

  local commands="init list current switch create delete rename export import backup uninstall doctor version help"

  if [[ ${COMP_CWORD} -eq 1 ]]; then
    COMPREPLY=( $(compgen -W "$commands" -- "$cur") )
    return 0
  fi

  local cmd="${COMP_WORDS[1]}"
  case "$cmd" in
    switch|use|delete|rm|rename|mv|export)
      local profiles
      profiles="$(claude-profiler list --quiet 2>/dev/null)"
      COMPREPLY=( $(compgen -W "$profiles" -- "$cur") )
      ;;
    create|new)
      case "$prev" in
        --from) local profiles; profiles="$(claude-profiler list --quiet 2>/dev/null)"
                COMPREPLY=( $(compgen -W "$profiles" -- "$cur") ) ;;
        *) COMPREPLY=( $(compgen -W "--from --empty" -- "$cur") ) ;;
      esac
      ;;
    backup)
      if [[ ${COMP_CWORD} -eq 2 ]]; then
        COMPREPLY=( $(compgen -W "list prune restore" -- "$cur") )
      fi
      ;;
    uninstall)
      COMPREPLY=( $(compgen -W "--restore --restore-origin --keep-data --archive-others --discard-others --keep-others --yes --force" -- "$cur") )
      ;;
    init)
      COMPREPLY=( $(compgen -W "--yes --no-git" -- "$cur") )
      ;;
    list|ls)
      COMPREPLY=( $(compgen -W "--quiet --json" -- "$cur") )
      ;;
    import)
      COMPREPLY=( $(compgen -f -- "$cur") )
      ;;
  esac
}

complete -F _claude_profiler_completions claude-profiler
