# RFC-6598 IP-Conserving Azure Databricks — Terraform

Deploys a VNet-injected Azure Databricks workspace into **non-routable RFC-6598
(`100.64.0.0/10`) shared address space**, with a two-firewall Azure Firewall
chain providing local SNAT and controlled egress. Databricks consumes
effectively **zero routable IPv4 space**.

This codifies the architecture validated end-to-end (a cluster in `100.64.x`
space egresses to the internet from Firewall 2's public IP).

## Architecture

```
RFC-6598 VNet (100.64.0.0/16)          FW1 VNet (10.29.0.0/24)      FW2 VNet (10.30.0.0/24)
┌─────────────────────────┐           ┌──────────────────┐         ┌──────────────────┐
│ Databricks public/private│  UDR      │ Azure Firewall 1 │  UDR    │ Azure Firewall 2 │  → Internet
│ (delegated, NPIP)        │ 0.0.0.0/0 │ LOCAL SNAT       │0.0.0.0/0│ egress + ADB rules│  → On-prem
│ + PE / utility / bastion │ ────────► │ forced tunnel    │ ──────► │ (auto-SNAT public)│
└─────────────────────────┘           └──────────────────┘         └──────────────────┘
        non-routable                      SNATs to 10.29.0.x          public IP egress
```

Traffic flow: cluster (`100.64.x`) → UDR → **FW1** (SNATs source to its own
`10.29.0.x`, forced-tunnels onward) → **FW2** (allows Databricks PaaS + egresses
to internet from its public IP).

## Usage

```bash
cp terraform.tfvars.example terraform.tfvars   # then edit
az login                                        # authenticate
terraform init
terraform plan
terraform apply
```

After apply, validate from a Databricks notebook:

```python
%sh
curl https://ipinfo.io/ip   # should return the egress_public_ip output (FW2)
```

## Files

| File | Purpose |
|------|---------|
| `versions.tf`    | Provider + version constraints |
| `variables.tf`   | Inputs (CIDRs, names, firewall tier) |
| `network.tf`     | VNets, subnets, Databricks delegation, NSG, peerings |
| `firewalls.tf`   | Both firewalls, policies, rules, SNAT, route tables |
| `databricks.tf`  | VNet-injected workspace |
| `outputs.tf`     | Workspace URL, firewall IPs, validation command |

## Key implementation notes

- **Local SNAT value is `255.255.255.255/32`, NOT `0.0.0.0/0`.** Azure Firewall
  does not SNAT traffic destined to its configured private ranges. A single
  `/32` means "treat almost nothing as private" → SNAT everything. Using
  `0.0.0.0/0` marks every destination as private and **disables SNAT**, which
  blackholes cluster traffic at FW2. This is the single most common mistake in
  this pattern.
- **FW2 rules allow both `100.64.0.0/16` and `10.29.0.0/24` as sources.**
  Traffic reaching FW2 has already been SNATed by FW1 to a `10.29.0.x` source,
  so that range must be permitted or the control-plane path fails.
- **Forced tunneling requires the management subnet + management IP config** on
  FW1 (`AzureFirewallManagementSubnet`).
- **Cost:** two Standard Azure Firewalls run ~$1.25/hr each plus data
  processing. Set `firewall_tier = "Premium"` only if you need TLS inspection /
  IDPS — and exclude certificate-pinning endpoints (Databricks control plane,
  some PaaS) from interception.

## Cost teardown

```bash
terraform destroy
```
