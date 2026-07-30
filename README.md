# DoTorDoH

Automatically chooses the best encrypted DNS transport for OpenWrt.

DoTorDoH uses `stubby` (DoT) and `https_dns_proxy` (DoH) to transparently switch
between **DNS-over-TLS (DoT)** and **DNS-over-HTTPS (DoH)** depending on network
conditions. On networks where outbound TCP/853 is blocked, it automatically
falls back to DoH. When DoT becomes available again, it switches back once
confidence in its availability is high enough.

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

Build the standalone script:

```sh
./bundle.zsh
```

Or execute directly from the source tree:

```sh
./bundle.zsh run
```

## Usage

```
dotordoh [COMMAND] [OPTIONS]
```

Available commands:

| Command | Description |
|-------|-------------|
| `monitor` | Automatically switch between DoT and DoH |
| `shield` | Advertise router DNS on IPv4 and IPv6 |

If no command is specified, the default command is `monitor`.

## Commands

### monitor

Starts the resolver and continuously monitors DoT availability. When TCP port
**853** is reachable, DoTorDoH uses DoT; otherwise, it switches to DoH.
Switching only occurs after several consecutive successful or failed probes,
which avoids oscillating between modes during unstable connectivity.

Example:

```sh
dotordoh monitor
```

### shield

Configures the local OpenWrt DNS services to forward all client queries
through the local resolver instance, overwriting WISP, ISP, and other DNS
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

Disabling PeerDNS requires the WAN interfaces to be reloaded. Pass `--boot` to
do this automatically, which is useful when running `shield` at boot:

```sh
dotordoh shield --boot
```

Waits until the local resolver instance is ready to accept DNS queries. It
repeatedly queries the local resolver until it becomes available, then
exits successfully. If the resolver does not become ready within the timeout
period, the command exits with an error.

Example:

```sh
dotordoh shield --wait
```

## Configuration

Configuration can be customized through `script.conf`.

Example:

```sh
LOCAL_PORT=5453

DOH_DOMAIN="cloudflare-dns.com"
DOH_PATH="/dns-query"

DOT_DOMAIN="1dot1dot1dot1.cloudflare-dns.com"

LAN_INTERFACE="lan"
WAN_INTERFACES="wan wan6"
```

## Automatic mode

Automatic mode works by periodically checking whether a TCP connection to the
configured DoT endpoint can be established. Each successful probe increases
confidence that DoT is available; each failed probe decreases it.

As confidence increases:

- Probes become less frequent
- Unnecessary network traffic is reduced
- Transient failures are ignored

Likewise, repeated failures eventually trigger a switch back to DoH.

## Requirements

The project relies on standard OpenWrt utilities, including:

- https_dns_proxy
- ip
- jsonfilter
- logger
- nc
- nslookup
- sleep
- stubby
- ubus
- uci

## License

[GPLv3][license]

*For commercial licensing, inquiries can be submitted via [stldo.com][website].*

Copyright (C) 2026-present stldo

[license]: ./LICENSE
[website]: https://stldo.com
