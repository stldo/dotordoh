# DoTorDoH [![License][1]][license]

Automatically chooses the best encrypted DNS transport for OpenWrt.

DoTorDoH uses `stubby` (DoT) and `https_dns_proxy` (DoH) to transparently switch
between **DNS-over-TLS (DoT)** and **DNS-over-HTTPS (DoH)** depending on network
conditions. On networks where outbound TCP/853 is blocked, it automatically
falls back to DoH. After a WAN interface change, it checks upstream reachability
and selects DoT when TCP/853 is reachable; otherwise, it uses DoH.

## Features

- Automatic DoT/DoH detection
- Automatic switching without restarting the router
- Minimal dependencies
- Built for OpenWrt
- Ensures only the router's DNS is advertised to clients

> The default configuration uses Cloudflare DNS.

## Installation

Clone the repository:

```sh
git clone https://github.com/stldo/dotordoh
cd dotordoh
```

Build the standalone command:

```sh
./bundle.zsh
```

The bundler requires Zsh and can be invoked from any working directory. It
creates `dist/usr/bin/dotordoh` for OpenWrt's `ash` and
`dist/etc/init.d/dotordoh` for procd. Imports are included once, with each
command checking its own direct and transitive requirements.

## Usage

```
dotordoh [COMMAND] [OPTIONS]
```

Available commands:

| Command | Description |
|-------|-------------|
| `monitor` | Automatically switch between DoT and DoH |
| `shield` | Advertise router DNS on IPv4 and IPv6 |

## Commands

### monitor

Starts the resolver and evaluates DoT availability. It first checks for upstream
reachability over TCP port **53**, then checks whether TCP port **853** is
reachable.

DoTorDoH uses DoT when it is reachable and otherwise switches to DoH. The
decision runs once during application boot and whenever a WAN interface change
with internet connectivity is detected.

Example:

```sh
dotordoh monitor
```

### shield

Configures the local OpenWrt DNS services to forward all client queries through
the local resolver instance, overwriting WISP, ISP, and other DNS
configurations.

- Disables PeerDNS on WAN interfaces
- Configures dnsmasq to advertise the router as the DNS server
- Enables DHCPv6
- Enables Router Advertisements
- Advertises the router's ULA through RDNSS

Example:

```sh
dotordoh shield
```

Disabling PeerDNS requires the WAN interfaces to be reloaded. Pass `-r` to
do this automatically, which is useful when running `shield` at boot:

```sh
dotordoh shield -r
```

Waits until the local resolver instance is ready to accept DNS queries. It
repeatedly queries the local resolver until it becomes available, then exits
successfully. If the resolver does not become ready within the timeout period,
the command exits with an error.

Example:

```sh
dotordoh shield -w
```

## Configuration

Configuration can be customized through `.env`.

Example:

```sh
LOCAL_PORT=5453
MONITOR_REACHABILITY_ATTEMPTS=12
MONITOR_REACHABILITY_DELAY=5

DOH_DOMAIN="cloudflare-dns.com"
DOH_PATH="/dns-query"

DOT_DOMAIN="1dot1dot1dot1.cloudflare-dns.com"

LAN_INTERFACE="lan"
WAN_INTERFACES="wan wan6"
```

### dnsmasq forwarding

Configure dnsmasq to forward client DNS queries to the local DoT/DoH resolver.
The forwarding port must match `LOCAL_PORT`:

```sh
uci set dhcp.@dnsmasq[0].noresolv='1'
uci delete dhcp.@dnsmasq[0].server
uci add_list dhcp.@dnsmasq[0].server='127.0.0.1#5453'
uci commit dhcp

/etc/init.d/dnsmasq restart
```

If `LOCAL_PORT` is changed, use the same port in the dnsmasq `server` value.
The resolver services listen on IPv4 loopback, so do not add `::1#5453` unless
you have separately configured them to listen on IPv6 loopback.

## Automatic mode

Automatic mode first checks whether any configured upstream can be reached on
TCP port **53**. If upstream reachability is available, it checks whether a TCP
connection to a configured DoT endpoint (port 853) can be established. If
reachable, DoT is used; otherwise, it falls back to DoH (port 443).

Mode selection runs:

- Once during application boot
- When a WAN interface change with internet connectivity is detected (e.g.
  connecting to a new Wi-Fi or cable network)

After each WAN interface change, the monitor retries the reachability check for
a short, bounded period while the connection is coming up. If reachability is
not established, it waits for the next WAN interface change.

Network/interface changes that do not result in an available internet connection
do not trigger the decision logic.

## Requirements

- GNU netcat
- https-dns-proxy
- Stubby

`apk add https-dns-proxy netcat stubby`

The project relies on other standard OpenWrt utilities, including:

- awk
- dnsmasq
- flock
- ifup
- ip
- jsonfilter
- nslookup
- sleep
- ubus
- uci

## License

[GPLv3][license]

*For commercial licensing, inquiries can be submitted via [stldo.com][website].*

Copyright (C) 2026-present stldo

[1]: https://img.shields.io/github/license/stldo/dotordoh
[license]: ./LICENSE
[website]: https://stldo.com
