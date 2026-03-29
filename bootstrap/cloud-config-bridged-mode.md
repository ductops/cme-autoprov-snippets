# Cloud Config Blades Malfunction
Software blades malfunction in Auto Scaling Group Gateways in Bridge Mode. 

Reference: https://sc1.checkpoint.com/documents/IaaS/WebAdminGuides/EN/CP_CloudGuard_Network_for_AWS_Gateway_Load_Balancer_ASG/Content/Topics-AWS-GWLB-ASG-DG/Troubleshooting.htm?tocpath=_____7#Troubleshooting

## cloud-config snippet
The eth0 interface of each Security Gateway is not set to "Internal" to work with Bridge Mode.


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
