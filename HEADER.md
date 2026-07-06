<!--
  Keep the title and badges OUTSIDE the centered <div>: the Terraform Registry's markdown renderer
  does not parse markdown inside an HTML block, so a # heading or [![badge]] in the div renders as
  literal text on the registry. Only the logo (HTML) goes in the div.
-->
<div align="center">
  <a href="https://libredevops.org">
    <picture>
      <source media="(prefers-color-scheme: dark)" srcset="https://libredevops.org/assets/libre-devops-white.png">
      <img alt="Libre DevOps" src="https://libredevops.org/assets/libre-devops-black.png" width="300">
    </picture>
  </a>
</div>

# Terraform Azure Public Load Balancer

Public (internet-facing) Azure load balancers with their backend pools, health probes,
load-balancing rules, outbound SNAT rules, and inbound NAT, cross-referenced by key.

[![CI](https://github.com/libre-devops/terraform-azurerm-public-lb/actions/workflows/ci.yml/badge.svg)](https://github.com/libre-devops/terraform-azurerm-public-lb/actions/workflows/ci.yml)
[![Release](https://img.shields.io/github/v/release/libre-devops/terraform-azurerm-public-lb?sort=semver&label=release)](https://github.com/libre-devops/terraform-azurerm-public-lb/releases/latest)
[![Terraform Registry](https://img.shields.io/badge/registry-libre--devops-7B42BC?logo=terraform&logoColor=white)](https://registry.terraform.io/namespaces/libre-devops)
[![License](https://img.shields.io/github/license/libre-devops/terraform-azurerm-public-lb)](./LICENSE)

---

## Overview

Public load balancers keyed by name. Every frontend references a **public ip or public ip prefix
created elsewhere**, the composition way (see the
[`public-ip`](https://registry.terraform.io/modules/libre-devops/public-ip/azurerm/latest) module);
for internal frontends use
[`private-lb`](https://registry.terraform.io/modules/libre-devops/private-lb/azurerm/latest)
instead. The split keeps each module's defaults honest: this module is only reached for when an
internet-facing endpoint is the point.

What the module adds over the bare resources:

- **One object per load balancer**: pools, probes, rules, outbound rules, and NAT wired together
  by key, so a rule says `backend_pool_keys = ["app"]` and `probe_key = "http"` instead of
  threading resource ids. Raw ids are still accepted for composition with resources built
  elsewhere.
- **Explicit outbound posture**: outbound SNAT is a first-class `outbound_rules` map, and when a
  load balancer defines outbound rules its load-balancing rules default to
  `disable_outbound_snat = true` (Azure requires that combination on a shared pool). A `check`
  block warns when a balancer relies on implicit SNAT.
- **Retired and wrong-fit SKUs rejected**: `sku` is validated to Standard (Basic is retired; the
  Gateway SKU is private-frontend only), and `sku_tier` accepts Global for the cross-region load
  balancer, whose pools reference regional frontends via `backend_address_ip_configuration_id`.
- **A probe nudge**: a `check` block warns when a load-balancing rule ships without a health probe.

The resource group is passed by id and parsed for the name and subscription.

## Usage

```hcl
module "public_ip" {
  source  = "libre-devops/public-ip/azurerm"
  version = "~> 4.0"

  resource_group_id = module.rg.ids["rg-ldo-uks-prd-001"]
  location          = "uksouth"
  tags              = module.tags.tags

  public_ips = { "pip-lbe-ldo-uks-prd-001" = {} }
}

module "public_lb" {
  source  = "libre-devops/public-lb/azurerm"
  version = "~> 4.0"

  resource_group_id = module.rg.ids["rg-ldo-uks-prd-001"]
  location          = "uksouth"
  tags              = module.tags.tags

  lbs = {
    "lbe-ldo-uks-prd-001" = {
      frontend_ip_configurations = {
        "public" = { public_ip_address_id = module.public_ip.public_ip_ids["pip-lbe-ldo-uks-prd-001"] }
      }

      backend_pools = { "app" = {} }

      probes = {
        "http" = { protocol = "Http", port = 8080, request_path = "/healthz" }
      }

      rules = {
        "app-https" = {
          frontend_port     = 443
          backend_port      = 8443
          backend_pool_keys = ["app"]
          probe_key         = "http"
        }
      }

      outbound_rules = {
        "egress" = { backend_pool_key = "app" }
      }
    }
  }
}
```

## Examples

- [`examples/minimal`](./examples/minimal) - one public load balancer on a zone-redundant public
  ip, with a backend pool, probe, and rule.
- [`examples/complete`](./examples/complete) - the full surface: two frontends (public ip and
  public ip prefix), explicit outbound rules with tuned SNAT ports, single-port and port-range NAT
  rules, and a legacy NAT pool.

## Developing

Local work needs **PowerShell 7+** and **[`just`](https://github.com/casey/just)**, because the recipes
wrap the [LibreDevOpsHelpers](https://www.powershellgallery.com/packages/LibreDevOpsHelpers)
PowerShell module (the same engine the `libre-devops/terraform-azure` action runs in CI). Install
just with `brew install just`, or `uv tool add rust-just` then `uv run just <recipe>`.

Run `just` to list recipes: `just update-ldo-pwsh` (install or force-update LibreDevOpsHelpers from
PSGallery), `just validate`, `just scan` (Trivy only), `just pwsh-analyze` (PSScriptAnalyzer only),
`just plan`, `just apply`, `just destroy`, `just e2e`, `just test`, and `just docs` (the
plan/apply/destroy recipes mirror the action, including the storage firewall dance; `just e2e`
applies an example then always destroys it, defaulting to `minimal`, so nothing is left running).
Releasing is also `just`:
`just increment-release [patch|minor|major]` bumps, tags, and publishes a GitHub release, and the
Terraform Registry picks up the tag.

## Security scan exceptions

This module is scanned with [Trivy](https://github.com/aquasecurity/trivy); HIGH and CRITICAL
findings fail the build. Any waiver is a deliberate, reviewed decision, never a way to quiet a
finding that should be fixed. Waivers live in [`.trivyignore.yaml`](./.trivyignore.yaml) (the
machine-applied source of truth, passed to Trivy with `--ignorefile`) and are mirrored in the table
below so the reason is auditable.

| Trivy ID | Resource | Finding | Justification |
|----------|----------|---------|---------------|
| _None_   |          |         |               |

To add an exception: add an entry to `.trivyignore.yaml` (`id`, optional `paths` to scope it, and a
`statement` recording why), then add a matching row here. Where the finding is out of this module's
scope, point the justification at the Libre DevOps module that does address it (for example the
private-endpoint module). Both the file and this table are reviewed in the pull request.

## Reference

The Requirements, Providers, Inputs, Outputs, and Resources below are generated by `terraform-docs`.
