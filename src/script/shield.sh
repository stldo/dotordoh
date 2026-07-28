#!/bin/ash

import core/shield/configure
import core/shield/verify
import utils/get_ipv4
import utils/get_ula

global lan_ipv4 "$(get_ipv4)"
global lan_ula "$(get_ula)"

shield_configure "$ARG_BOOT"
shield_verify
