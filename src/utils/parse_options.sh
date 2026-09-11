#!/bin/ash

require tr

parse_options() {
  local OPTARG OPTIND=1 key option spec="${1:-}" value

  eval "set -- $ARGUMENTS"

  while getopts ":$spec" option; do
    case "$option" in
      \?)
        error "'$COMMAND' doesn't support option '-$OPTARG'"
        ;;
      :)
        error "'$COMMAND' option '-$OPTARG' requires a value"
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

  [ "$#" -eq 0 ] || error "'$COMMAND' doesn't support positional arguments"
}
