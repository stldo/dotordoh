#!/bin/ash

import utils/parse_options

parse_options hv

if [ -n "${OPTION_V:-}" ]; then
  printf '%s\n' "DoTorDoH $APP_VERSION"
  exit 0
fi

USAGE_MESSAGE=$(printf '%s\n\n%s\n%s\n%s\n%s' \
  '%s %s' \
  'Copyright (C) %s-present %s' \
  'This program comes with ABSOLUTELY NO WARRANTY. This is free software, ' \
  'and you are welcome to redistribute it under certain conditions; visit ' \
  '%s for details.')

printf "$USAGE_MESSAGE\n\n" \
  "DoTorDoH" \
  "$APP_VERSION" \
  "2026" \
  "stldo" \
  "https://github.com/stldo/dotordoh"

printf '%s\n\n' "Usage: $0 [COMMAND] [OPTIONS]"

printf '%s\n' 'Options:'
printf '%s\n' '  -h       Show this help message'
printf '%s\n\n' '  -v       Show version'

printf '%s\n' 'Commands:'
printf '%s\n' '  install  Install and initialize DoTorDoH'
printf '%s\n' '  monitor  Automatically switch between DoT and DoH'
printf '%s\n\n' '  shield   Advertise router DNS on IPv4 and IPv6'

printf '%s\n' 'Shield options:'
printf '%s\n' '  -w       Wait for the local resolver to become ready'
