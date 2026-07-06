<!--
  Header for the complete example README. Edit this file, then run `just docs`
  (or ./Sort-LdoTerraform.ps1 -IncludeExamples) to regenerate the section between the markers.
  The example's main.tf is embedded into the README automatically (see .terraform-docs.yml).
-->
<div align="center">
  <a href="https://libredevops.org">
    <picture>
      <source media="(prefers-color-scheme: dark)" srcset="https://libredevops.org/assets/libre-devops-white.png">
      <img alt="Libre DevOps" src="https://libredevops.org/assets/libre-devops-black.png" width="200">
    </picture>
  </a>
</div>

# Complete example

The full surface of the module on one public load balancer: two frontends (a zone-redundant
public ip for inbound and a public ip prefix dedicated to SNAT), Tcp and Http probes, Https and
Udp rules (with disable_outbound_snat defaulted on by the module because outbound rules exist), an
explicit outbound rule with tuned port allocation, single-port and port-range NAT rules, and a
legacy NAT pool. The environment comes from the Terraform workspace (`terraform.workspace`), not a
variable. Run it with `just e2e complete`, which applies the stack then always destroys it.

[![Terraform Registry](https://img.shields.io/badge/registry-libre--devops-7B42BC?logo=terraform&logoColor=white)](https://registry.terraform.io/namespaces/libre-devops)

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.9.0, < 2.0.0 |
| <a name="requirement_azurerm"></a> [azurerm](#requirement\_azurerm) | >= 4.0.0, < 5.0.0 |

## Providers

No providers.

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_public_ip"></a> [public\_ip](#module\_public\_ip) | libre-devops/public-ip/azurerm | ~> 4.0 |
| <a name="module_public_lb"></a> [public\_lb](#module\_public\_lb) | ../../ | n/a |
| <a name="module_rg"></a> [rg](#module\_rg) | libre-devops/rg/azurerm | ~> 4.0 |
| <a name="module_tags"></a> [tags](#module\_tags) | libre-devops/tags/azurerm | ~> 4.0 |

## Resources

No resources.

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_deployed_branch"></a> [deployed\_branch](#input\_deployed\_branch) | Git branch the deployment came from. Auto-filled in CI from TF\_VAR\_deployed\_branch. | `string` | `""` | no |
| <a name="input_deployed_repo"></a> [deployed\_repo](#input\_deployed\_repo) | Repository URL the deployment came from. Auto-filled in CI from TF\_VAR\_deployed\_repo. | `string` | `""` | no |
| <a name="input_loc"></a> [loc](#input\_loc) | Outfix: short Azure region code used in resource names (for example uks). | `string` | `"uks"` | no |
| <a name="input_regions"></a> [regions](#input\_regions) | Map of short region codes to Azure region slugs. | `map(string)` | <pre>{<br/>  "eus": "eastus",<br/>  "euw": "westeurope",<br/>  "uks": "uksouth",<br/>  "ukw": "ukwest"<br/>}</pre> | no |
| <a name="input_short"></a> [short](#input\_short) | Infix: short product code used in resource names. | `string` | `"ldo"` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_backend_pool_ids"></a> [backend\_pool\_ids](#output\_backend\_pool\_ids) | Backend pool ids keyed by "<lb>/<pool>". |
| <a name="output_frontend_ip_configurations"></a> [frontend\_ip\_configurations](#output\_frontend\_ip\_configurations) | Frontend configurations as returned by Azure. |
| <a name="output_lb_ids"></a> [lb\_ids](#output\_lb\_ids) | Map of load balancer name to resource id. |
| <a name="output_outbound_rule_ids"></a> [outbound\_rule\_ids](#output\_outbound\_rule\_ids) | Outbound rule ids keyed by "<lb>/<rule>". |
| <a name="output_public_ip_address"></a> [public\_ip\_address](#output\_public\_ip\_address) | The public ip the load balancer fronts. |
<!-- END_TF_DOCS -->
