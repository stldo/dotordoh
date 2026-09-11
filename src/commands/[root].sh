#!/bin/ash

import utils/parse_options

parse_options h

USAGE_MESSAGE=$(printf '%s\n%s\n%s%s\n%s' \
  '%s Copyright (C) %s-present %s' \
  'This program comes with ABSOLUTELY NO WARRANTY. This is free software, ' \
  'and you ' \
  'are welcome to redistribute it under certain conditions; visit ' \
  '%s for details.')

printf "$USAGE_MESSAGE" \
  "DoTorDoH" \
  "2026" \
  "stldo" \
  "https://github.com/stldo/dotordoh"

printf '\n\n%s\n' "Usage: $0 [COMMAND] [OPTIONS]"
printf '\n%s\n' 'Commands:'
printf '%s\n' '  install  Install and initialize DoTorDoH'
printf '%s\n' '  monitor  Automatically switch between DoT and DoH'
printf '%s\n' '  shield   Advertise router DNS on IPv4 and IPv6'
printf '\n%s\n' 'Shield options:'
printf '%s\n' '  -w       Wait for the local resolver to become ready'
