#!/bin/ash

list_to_args() {
  local item result

  (
    set -f

    result=

    [ -z "$1" ] && return 0

    for item in $1; do
      if [ -n "$result" ]; then
        result="${result} $2 $item"
      else
        result="$2 $item"
      fi
    done

    printf '%s\n' "$result"
  )
}
