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

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.9.0, < 2.0.0 |
| <a name="requirement_azurerm"></a> [azurerm](#requirement\_azurerm) | >= 4.0.0, < 5.0.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_azurerm"></a> [azurerm](#provider\_azurerm) | >= 4.0.0, < 5.0.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [azurerm_lb.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/lb) | resource |
| [azurerm_lb_backend_address_pool.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/lb_backend_address_pool) | resource |
| [azurerm_lb_backend_address_pool_address.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/lb_backend_address_pool_address) | resource |
| [azurerm_lb_nat_pool.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/lb_nat_pool) | resource |
| [azurerm_lb_nat_rule.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/lb_nat_rule) | resource |
| [azurerm_lb_outbound_rule.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/lb_outbound_rule) | resource |
| [azurerm_lb_probe.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/lb_probe) | resource |
| [azurerm_lb_rule.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/lb_rule) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_lbs"></a> [lbs](#input\_lbs) | Public (internet-facing) load balancers to create, keyed by load balancer name. Every frontend<br/>references a public ip or public ip prefix created elsewhere (compose the public-ip module);<br/>use the private-lb module for internal frontends. Fields:<br/>  sku        Standard only: Basic is retired and rejected, and the Gateway SKU is<br/>             private-frontend only, so it lives in the private-lb module.<br/>  sku\_tier   Regional (default) or Global. Global is the cross-region load balancer: its<br/>             backend pool addresses reference regional load balancer frontends via<br/>             backend\_address\_ip\_configuration\_id.<br/>  edge\_zone  Edge Zone the load balancer lives in.<br/>  tags       Per-load-balancer tags (falls back to the module tags when null).<br/>  frontend\_ip\_configurations  Public frontends keyed by frontend name: exactly one of<br/>             public\_ip\_address\_id or public\_ip\_prefix\_id. Zone redundancy rides on the public<br/>             ip itself, not the frontend.<br/>  backend\_pools  Backend address pools keyed by pool name. virtual\_network\_id enables<br/>             IP-based backends (with optional synchronous\_mode); addresses is a map of<br/>             IP-based backend addresses keyed by address name (on a Global tier balancer,<br/>             addresses point at regional frontends via backend\_address\_ip\_configuration\_id).<br/>  probes     Health probes keyed by probe name. protocol defaults to Tcp; Http and Https<br/>             require request\_path.<br/>  rules      Load-balancing rules keyed by rule name. Reference module-built objects by key<br/>             (backend\_pool\_keys, probe\_key) or pass raw ids (backend\_address\_pool\_ids,<br/>             probe\_id). frontend\_ip\_configuration\_name may be omitted when the load balancer<br/>             has exactly one frontend. When the load balancer defines outbound\_rules,<br/>             disable\_outbound\_snat defaults to true on every rule (required by Azure when<br/>             inbound and outbound rules share a pool, and the explicit-outbound posture).<br/>  outbound\_rules  Outbound SNAT rules keyed by rule name: the explicit, recommended way to<br/>             give backends internet egress. backend\_pool\_key or backend\_address\_pool\_id picks<br/>             the pool; frontend\_ip\_configuration\_names picks the frontends (defaults to all of<br/>             the load balancer's frontends); allocated\_outbound\_ports tunes SNAT port<br/>             allocation.<br/>  nat\_rules  Inbound NAT rules keyed by rule name: either a single frontend\_port, or a<br/>             frontend\_port\_start/frontend\_port\_end range targeting a backend pool (by<br/>             backend\_pool\_key or backend\_address\_pool\_id).<br/>  nat\_pools  Legacy inbound NAT pools keyed by pool name (superseded by port-range NAT rules;<br/>             kept for VMSS setups that still need them). | <pre>map(object({<br/>    sku       = optional(string, "Standard")<br/>    sku_tier  = optional(string, "Regional")<br/>    edge_zone = optional(string)<br/>    tags      = optional(map(string))<br/><br/>    frontend_ip_configurations = map(object({<br/>      public_ip_address_id = optional(string)<br/>      public_ip_prefix_id  = optional(string)<br/>    }))<br/><br/>    backend_pools = optional(map(object({<br/>      virtual_network_id = optional(string)<br/>      synchronous_mode   = optional(string)<br/>      addresses = optional(map(object({<br/>        virtual_network_id                  = optional(string)<br/>        ip_address                          = optional(string)<br/>        backend_address_ip_configuration_id = optional(string)<br/>      })), {})<br/>    })), {})<br/><br/>    probes = optional(map(object({<br/>      protocol            = optional(string, "Tcp")<br/>      port                = number<br/>      request_path        = optional(string)<br/>      interval_in_seconds = optional(number)<br/>      number_of_probes    = optional(number)<br/>      probe_threshold     = optional(number)<br/>    })), {})<br/><br/>    rules = optional(map(object({<br/>      protocol                       = optional(string, "Tcp")<br/>      frontend_port                  = number<br/>      backend_port                   = number<br/>      frontend_ip_configuration_name = optional(string)<br/>      backend_pool_keys              = optional(list(string), [])<br/>      backend_address_pool_ids       = optional(list(string), [])<br/>      probe_key                      = optional(string)<br/>      probe_id                       = optional(string)<br/>      floating_ip_enabled            = optional(bool)<br/>      tcp_reset_enabled              = optional(bool)<br/>      idle_timeout_in_minutes        = optional(number)<br/>      load_distribution              = optional(string)<br/>      disable_outbound_snat          = optional(bool)<br/>    })), {})<br/><br/>    outbound_rules = optional(map(object({<br/>      protocol                        = optional(string, "All")<br/>      backend_pool_key                = optional(string)<br/>      backend_address_pool_id         = optional(string)<br/>      frontend_ip_configuration_names = optional(list(string))<br/>      allocated_outbound_ports        = optional(number)<br/>      idle_timeout_in_minutes         = optional(number)<br/>      tcp_reset_enabled               = optional(bool)<br/>    })), {})<br/><br/>    nat_rules = optional(map(object({<br/>      protocol                       = optional(string, "Tcp")<br/>      backend_port                   = number<br/>      frontend_port                  = optional(number)<br/>      frontend_port_start            = optional(number)<br/>      frontend_port_end              = optional(number)<br/>      backend_pool_key               = optional(string)<br/>      backend_address_pool_id        = optional(string)<br/>      frontend_ip_configuration_name = optional(string)<br/>      floating_ip_enabled            = optional(bool)<br/>      tcp_reset_enabled              = optional(bool)<br/>      idle_timeout_in_minutes        = optional(number)<br/>    })), {})<br/><br/>    nat_pools = optional(map(object({<br/>      protocol                       = optional(string, "Tcp")<br/>      frontend_port_start            = number<br/>      frontend_port_end              = number<br/>      backend_port                   = number<br/>      frontend_ip_configuration_name = optional(string)<br/>      floating_ip_enabled            = optional(bool)<br/>      tcp_reset_enabled              = optional(bool)<br/>      idle_timeout_in_minutes        = optional(number)<br/>    })), {})<br/>  }))</pre> | `{}` | no |
| <a name="input_location"></a> [location](#input\_location) | Azure region for the load balancers. | `string` | n/a | yes |
| <a name="input_resource_group_id"></a> [resource\_group\_id](#input\_resource\_group\_id) | Resource id of the resource group the load balancers are created in. The resource group name and subscription are parsed from this id. | `string` | n/a | yes |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags applied to the load balancers (unless a load balancer sets its own). | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_backend_pool_address_ids"></a> [backend\_pool\_address\_ids](#output\_backend\_pool\_address\_ids) | Map of "<lb>/<pool>/<address>" to the backend pool address resource id. |
| <a name="output_backend_pool_ids"></a> [backend\_pool\_ids](#output\_backend\_pool\_ids) | Map of "<lb>/<pool>" to the backend address pool resource id. |
| <a name="output_backend_pool_ids_zipmap"></a> [backend\_pool\_ids\_zipmap](#output\_backend\_pool\_ids\_zipmap) | Map of "<lb>/<pool>" to a { name, id } object for the backend address pool. |
| <a name="output_frontend_ip_configurations"></a> [frontend\_ip\_configurations](#output\_frontend\_ip\_configurations) | Map of load balancer name to its frontend ip configurations as returned by Azure (name, id, public ip references). |
| <a name="output_ids"></a> [ids](#output\_ids) | Map of load balancer name to its resource id. |
| <a name="output_ids_zipmap"></a> [ids\_zipmap](#output\_ids\_zipmap) | Map of load balancer name to a { name, id } object, for passing where both are needed together. |
| <a name="output_names"></a> [names](#output\_names) | The load balancer names. |
| <a name="output_nat_pool_ids"></a> [nat\_pool\_ids](#output\_nat\_pool\_ids) | Map of "<lb>/<pool>" to the inbound NAT pool resource id. |
| <a name="output_nat_rule_ids"></a> [nat\_rule\_ids](#output\_nat\_rule\_ids) | Map of "<lb>/<rule>" to the inbound NAT rule resource id. |
| <a name="output_outbound_rule_ids"></a> [outbound\_rule\_ids](#output\_outbound\_rule\_ids) | Map of "<lb>/<rule>" to the outbound rule resource id. |
| <a name="output_probe_ids"></a> [probe\_ids](#output\_probe\_ids) | Map of "<lb>/<probe>" to the health probe resource id. |
| <a name="output_resource_group_name"></a> [resource\_group\_name](#output\_resource\_group\_name) | Resource group name parsed from resource\_group\_id. |
| <a name="output_rule_ids"></a> [rule\_ids](#output\_rule\_ids) | Map of "<lb>/<rule>" to the load-balancing rule resource id. |
| <a name="output_subscription_id"></a> [subscription\_id](#output\_subscription\_id) | Subscription id parsed from resource\_group\_id. |
| <a name="output_tags"></a> [tags](#output\_tags) | The tags applied to the load balancers. |
<!-- END_TF_DOCS -->
