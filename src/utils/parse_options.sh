#!/bin/ash

require tr

parse_options() {
  local OPTARG OPTIND=1 command key option spec="${1:-}" value

  if [ -n "$COMMAND" ]; then
    command=" in '$COMMAND'"
  else
    command=""
  fi

  eval "set -- $ARGUMENTS"

  while getopts ":$spec" option; do
    case "$option" in
      \?)
        error "Option '-$OPTARG' is not supported${command}"
        ;;
      :)
        error "Option '-$OPTARG' requires a value${command}"
        ;;
      *)
        key=$(printf '%s' "$option" | tr 'a-z' 'A-Z')
        case "$spec" in
          *"$option:"*) value="$OPTARG" ;;
          *) value=1 ;;
        esac
        eval "OPTION_$key=\"\$value\""
        ;;
    esac
  done

  shift $((OPTIND - 1))

  [ "$#" -eq 0 ] || error "Positional arguments are not supported${command}"
}
