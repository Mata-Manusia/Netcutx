# netcutx

LAN access control tool for macOS. Cuts or intercepts network connections on your local network via ARP spoofing.

> **For authorized use only.** Use on networks you own or have explicit permission to test.

## Features

- Auto-detect interface, gateway, and local devices
- Network scan via ARP (active + cache)
- **Multi-target mass deauth** — cut multiple devices simultaneously
- Two attack modes: cut connection or full MITM
- Graceful restore on exit (Ctrl+C)

## Requirements

- macOS (uses BPF — `/dev/bpf*`)
- Xcode Command Line Tools
- `sudo` (BPF requires root)

## Build

```bash
make
```

Binary outputs to `build/netcutx`.

## Usage

### Interactive mode

```bash
sudo ./build/netcutx
```

Follow prompts:
1. Select network interface
2. Tool scans network, lists devices
3. Select target(s)
4. Select mode
5. Confirm — spoofing starts
6. `Ctrl+C` to stop and restore ARP tables

### CLI mode

```bash
sudo ./build/netcutx <victim-ip> [options]
```

| Option | Description |
|--------|-------------|
| `-i, --interface <name>` | Network interface (default: auto-detect) |
| `-g, --gateway <ip>` | Gateway IP (default: auto-detect) |
| `-r, --repeat <secs>` | Spoof interval in seconds (default: 2) |
| `-b, --bidirectional` | Bidirectional spoof (full MITM) |
| `-f, --forward` | Enable IP forwarding (use with `-b`) |
| `-v, --verbose` | Verbose output |

**Examples:**

```bash
# Cut single target
sudo ./build/netcutx 192.168.1.100

# Full MITM with traffic forwarding
sudo ./build/netcutx 192.168.1.100 -b -f

# Specify interface and gateway
sudo ./build/netcutx 192.168.1.100 -i en0 -g 192.168.1.1
```

## Attack Modes

### Mode 1 — Cut connection

Poisons victim's ARP cache (gateway IP → attacker MAC) and gateway's ARP cache (victim IP → attacker MAC). Traffic from both sides flows to attacker and is dropped, cutting the target's internet access.

Sends per interval:
- Unicast ARP reply to victim: `gateway IP → our MAC`
- Broadcast ARP: `gateway IP → our MAC`
- Unicast to gateway: `victim IP → our MAC`
- Broadcast: `victim IP → our MAC` (bypasses gateway ARP filtering)

### Mode 2 — Full MITM (bidirectional)

Same as Mode 1 but enables IP forwarding so traffic passes through the attacker. Intercept, inspect, or modify traffic in both directions.

## Multi-target (mass deauth)

In interactive mode, select multiple targets at the device list prompt:

```
Pilih target [1-5] / pisah koma (mis: 3,4,5) / "all"  3,4,5
```

```
Pilih target [1-5] / pisah koma (mis: 3,4,5) / "all"  all
```

All selected targets are spoofed in a single loop per interval. `Ctrl+C` restores ARP tables for all targets.

## How it works

netcutx uses macOS BPF (Berkeley Packet Filter) to send raw Ethernet frames directly. No `libpcap` dependency — BPF is accessed via the kernel's `/dev/bpf*` devices.

ARP spoofing flow:
```
Victim ARP cache:  gateway IP → attacker MAC  (victim sends to attacker)
Gateway ARP cache: victim IP  → attacker MAC  (gateway sends to attacker)
```

Without IP forwarding: packets dropped → target loses internet.  
With IP forwarding: packets relayed → MITM.

## Clean

```bash
make clean
```

## Version

v1.0.0
