resource "azurerm_public_ip" "pip" {
  count = var.pip_sku == null ? 0 : 1

  name                = var.pip_name
  location            = var.location
  resource_group_name = var.rg_name
  allocation_method   = "Static"
  domain_name_label   = coalesce(var.pip_custom_dns_label, var.lb_name)
  sku                 = var.pip_sku
  zones               = var.availability_zone
}