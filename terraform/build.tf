module "rg" {
  source = "registry.terraform.io/libre-devops/rg/azurerm"

  rg_name  = "rg-${var.short}-${var.loc}-${terraform.workspace}-build" // rg-ldo-euw-dev-build
  location = local.location                                            // compares var.loc with the var.regions var to match a long-hand name, in this case, "euw", so "westeurope"
  tags     = local.tags

  #  lock_level = "CanNotDelete" // Do not set this value to skip lock
}

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