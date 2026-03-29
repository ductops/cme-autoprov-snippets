




```bash
#cloud-config

network:

  version: 1

  config:

  - type: bridge

    name: br0

    mtu: *eth0-mtu

    subnets:

      - address: *eth0-private

        type: static

        gateway: *default-gateway

        dns_nameservers:

        - *eth0-dns1

    bridge_interfaces:

      - eth0
```
