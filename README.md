```hcl
module "public_lb" {
  source = "github.com/libre-devops/terraform-azurerm-public-lb"

  rg_name  = module.rg.rg_name
  location = module.rg.rg_location
  tags     = module.rg.rg_tags

  pip_name          = "pip-lbe-${var.short}-${var.loc}-${terraform.workspace}-01"
  pip_sku           = "Standard"
  availability_zone = ["1"]

  lb_name                  = "lbe-${var.short}-${var.loc}-${terraform.workspace}-01"
  lb_bpool_name            = "bpool-${module.public_lb.lb_name}"
  lb_ip_configuration_name = "lbe-${var.short}-${var.loc}-${terraform.workspace}-01-ipconfig"

  enable_outbound_rule     = true
  outbound_rule_name       = "rule-out-${module.public_lb.lb_name}"
  outbound_protocol        = "Tcp"
  allocated_outbound_ports = 1024
}

```

For a full example build, check out the [Libre DevOps Website](https://www.libredevops.org/quickstart/utils/terraform/using-lbdo-tf-modules-example.html)

## Requirements

No requirements.

## Providers

| Name | Version |
|------|---------|
| <a name="provider_azurerm"></a> [azurerm](#provider\_azurerm) | n/a |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [azurerm_lb.pub_lb](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/lb) | resource |
| [azurerm_lb_backend_address_pool.public_lb_bpool](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/lb_backend_address_pool) | resource |
| [azurerm_lb_outbound_rule.outbound_rule](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/lb_outbound_rule) | resource |
| [azurerm_public_ip.pip](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/public_ip) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_allocated_outbound_ports"></a> [allocated\_outbound\_ports](#input\_allocated\_outbound\_ports) | The number of ports allocated for the outbound rule | `number` | n/a | yes |
| <a name="input_allocation_method"></a> [allocation\_method](#input\_allocation\_method) | Defines how an IP address is assigned. Options are Static or Dynamic. | `string` | `"Dynamic"` | no |
| <a name="input_availability_zone"></a> [availability\_zone](#input\_availability\_zone) | The availability zone for the PIP to be created to | `list(any)` | n/a | yes |
| <a name="input_enable_outbound_rule"></a> [enable\_outbound\_rule](#input\_enable\_outbound\_rule) | Whether an outbound rule should be made | `bool` | n/a | yes |
| <a name="input_lb_bpool_name"></a> [lb\_bpool\_name](#input\_lb\_bpool\_name) | The name for the backend pool for the Load Balancer | `string` | n/a | yes |
| <a name="input_lb_ip_configuration_name"></a> [lb\_ip\_configuration\_name](#input\_lb\_ip\_configuration\_name) | The name of the frontend IP Configuration name | `string` | n/a | yes |
| <a name="input_lb_name"></a> [lb\_name](#input\_lb\_name) | The name of the LB | `string` | n/a | yes |
| <a name="input_lb_sku_name"></a> [lb\_sku\_name](#input\_lb\_sku\_name) | The SKU of the lb | `string` | `"Standard"` | no |
| <a name="input_location"></a> [location](#input\_location) | The location for this resource to be put in | `string` | n/a | yes |
| <a name="input_outbound_protocol"></a> [outbound\_protocol](#input\_outbound\_protocol) | The protocol for the outbound rule | `string` | n/a | yes |
| <a name="input_outbound_rule_name"></a> [outbound\_rule\_name](#input\_outbound\_rule\_name) | The name of the outbound rule | `string` | n/a | yes |
| <a name="input_pip_custom_dns_label"></a> [pip\_custom\_dns\_label](#input\_pip\_custom\_dns\_label) | If you are using a public IP and wish to assign a custom DNS label, set here, otherwise, the VM host name will be used | `any` | `null` | no |
| <a name="input_pip_name"></a> [pip\_name](#input\_pip\_name) | If you are using a Public IP, set the name in this variable | `string` | `null` | no |
| <a name="input_pip_sku"></a> [pip\_sku](#input\_pip\_sku) | If you wish to assign a public IP directly, set this to Standard | `string` | `null` | no |
| <a name="input_rg_name"></a> [rg\_name](#input\_rg\_name) | The name of the resource group, this module does not create a resource group, it is expecting the value of a resource group already exists | `string` | n/a | yes |
| <a name="input_tags"></a> [tags](#input\_tags) | A map of the tags to use on the resources that are deployed with this module. | `map(string)` | <pre>{<br>  "source": "terraform"<br>}</pre> | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_bpool_id"></a> [bpool\_id](#output\_bpool\_id) | The id of the backend pool |
| <a name="output_bpool_name"></a> [bpool\_name](#output\_bpool\_name) | The name of the backend pool |
| <a name="output_lb_id"></a> [lb\_id](#output\_lb\_id) | The ID of the load balancer |
| <a name="output_lb_ip_configuration"></a> [lb\_ip\_configuration](#output\_lb\_ip\_configuration) | The frontend ip configuration object |
| <a name="output_lb_name"></a> [lb\_name](#output\_lb\_name) | The Name of the load balancer |
| <a name="output_outbound_allocated_outbound_ports"></a> [outbound\_allocated\_outbound\_ports](#output\_outbound\_allocated\_outbound\_ports) | The allocated ports of the outbound rule if created |
| <a name="output_outbound_rule_id"></a> [outbound\_rule\_id](#output\_outbound\_rule\_id) | The id of the outbound rule if created |
| <a name="output_outbound_rule_name"></a> [outbound\_rule\_name](#output\_outbound\_rule\_name) | The name of the outbound rule if created |
| <a name="output_outbound_rule_protocol"></a> [outbound\_rule\_protocol](#output\_outbound\_rule\_protocol) | The protocl of the outbound rule if created |
| <a name="output_pip_id"></a> [pip\_id](#output\_pip\_id) | The id of the public ip |
| <a name="output_pip_ip_address"></a> [pip\_ip\_address](#output\_pip\_ip\_address) | The address of the public ip |
| <a name="output_pip_name"></a> [pip\_name](#output\_pip\_name) | The name of the public ip |
