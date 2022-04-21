resource "azurerm_lb" "pub_lb" {
  location            = var.location
  name                = var.lb_name
  resource_group_name = var.rg_name

  sku = var.lb_sku_name

  dynamic "frontend_ip_configuration" {
    for_each = azurerm_public_ip.pip
    content {
      name                 = var.lb_ip_configuration_name
      public_ip_address_id = frontend_ip_configuration.value.id
      availability_zone    = var.availability_zone
    }
  }

  tags = var.tags
}

resource "azurerm_lb_backend_address_pool" "public_lb_bpool" {
  loadbalancer_id = azurerm_lb.pub_lb.id
  name            = var.lb_bpool_name
}

resource "azurerm_lb_outbound_rule" "outbound_rule" {
  count = var.enable_outbound_rule ? 1 : 0

  name                = var.outbound_rule_name
  resource_group_name = var.rg_name

  backend_address_pool_id  = azurerm_lb_backend_address_pool.public_lb_bpool.id
  loadbalancer_id          = azurerm_lb.pub_lb.id
  protocol                 = title(var.outbound_protocol)
  allocated_outbound_ports = var.allocated_outbound_ports

  frontend_ip_configuration {
    name = var.lb_ip_configuration_name
  }
}