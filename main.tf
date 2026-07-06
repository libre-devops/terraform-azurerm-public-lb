# Public (internet-facing) Standard load balancers keyed by name, with their backend pools, health
# probes, load-balancing rules, outbound SNAT rules, and inbound NAT, all cross-referenced by key.
# Every frontend references a public ip or public ip prefix created elsewhere (compose the
# public-ip module); internal frontends live in the private-lb module. When outbound rules are
# defined, load-balancing rules default to disable_outbound_snat = true, the explicit-outbound
# posture Azure requires when inbound and outbound rules share a pool. Basic is rejected: it is
# retired. The resource group is passed by id and parsed.
locals {
  rg                  = provider::azurerm::parse_resource_id(var.resource_group_id)
  resource_group_name = local.rg.resource_group_name

  # A rule may omit frontend_ip_configuration_name when the load balancer has exactly one frontend
  # (validated); resolve that default once.
  default_frontend_name = {
    for name, lb in var.lbs : name => length(lb.frontend_ip_configurations) == 1 ? keys(lb.frontend_ip_configurations)[0] : null
  }

  # Flatten the children to "<lb>/<child>" keys.
  backend_pools = merge([
    for lb_name, lb in var.lbs : {
      for pool_name, p in lb.backend_pools : "${lb_name}/${pool_name}" => {
        lb_name   = lb_name
        pool_name = pool_name
        pool      = p
      }
    }
  ]...)

  backend_pool_addresses = merge([
    for pool_key, bp in local.backend_pools : {
      for addr_name, a in bp.pool.addresses : "${pool_key}/${addr_name}" => {
        pool_key  = pool_key
        addr_name = addr_name
        address   = a
      }
    }
  ]...)

  probes = merge([
    for lb_name, lb in var.lbs : {
      for probe_name, p in lb.probes : "${lb_name}/${probe_name}" => {
        lb_name    = lb_name
        probe_name = probe_name
        probe      = p
      }
    }
  ]...)

  rules = merge([
    for lb_name, lb in var.lbs : {
      for rule_name, r in lb.rules : "${lb_name}/${rule_name}" => {
        lb_name   = lb_name
        rule_name = rule_name
        rule      = r
        # Explicit outbound rules mean inbound rules must not also SNAT (and Azure rejects the
        # combination on a shared pool), so that becomes the default.
        disable_outbound_snat = coalesce(r.disable_outbound_snat, length(lb.outbound_rules) > 0)
      }
    }
  ]...)

  outbound_rules = merge([
    for lb_name, lb in var.lbs : {
      for rule_name, o in lb.outbound_rules : "${lb_name}/${rule_name}" => {
        lb_name   = lb_name
        rule_name = rule_name
        rule      = o
        # Default to SNAT through all of the load balancer's frontends.
        frontend_names = coalesce(o.frontend_ip_configuration_names, keys(lb.frontend_ip_configurations))
      }
    }
  ]...)

  nat_rules = merge([
    for lb_name, lb in var.lbs : {
      for rule_name, r in lb.nat_rules : "${lb_name}/${rule_name}" => {
        lb_name   = lb_name
        rule_name = rule_name
        rule      = r
      }
    }
  ]...)

  nat_pools = merge([
    for lb_name, lb in var.lbs : {
      for pool_name, p in lb.nat_pools : "${lb_name}/${pool_name}" => {
        lb_name   = lb_name
        pool_name = pool_name
        pool      = p
      }
    }
  ]...)
}

resource "azurerm_lb" "this" {
  for_each = var.lbs

  resource_group_name = local.resource_group_name
  location            = var.location
  tags                = each.value.tags != null ? each.value.tags : var.tags

  name      = each.key
  sku       = each.value.sku
  sku_tier  = each.value.sku_tier
  edge_zone = each.value.edge_zone

  dynamic "frontend_ip_configuration" {
    for_each = each.value.frontend_ip_configurations

    content {
      name                 = frontend_ip_configuration.key
      public_ip_address_id = frontend_ip_configuration.value.public_ip_address_id
      public_ip_prefix_id  = frontend_ip_configuration.value.public_ip_prefix_id
    }
  }
}

resource "azurerm_lb_backend_address_pool" "this" {
  for_each = local.backend_pools

  loadbalancer_id = azurerm_lb.this[each.value.lb_name].id

  name               = each.value.pool_name
  virtual_network_id = each.value.pool.virtual_network_id
  synchronous_mode   = each.value.pool.synchronous_mode
}

resource "azurerm_lb_backend_address_pool_address" "this" {
  for_each = local.backend_pool_addresses

  backend_address_pool_id = azurerm_lb_backend_address_pool.this[each.value.pool_key].id

  name                                = each.value.addr_name
  virtual_network_id                  = each.value.address.virtual_network_id
  ip_address                          = each.value.address.ip_address
  backend_address_ip_configuration_id = each.value.address.backend_address_ip_configuration_id
}

resource "azurerm_lb_probe" "this" {
  for_each = local.probes

  loadbalancer_id = azurerm_lb.this[each.value.lb_name].id

  name                = each.value.probe_name
  protocol            = each.value.probe.protocol
  port                = each.value.probe.port
  request_path        = each.value.probe.request_path
  interval_in_seconds = each.value.probe.interval_in_seconds
  number_of_probes    = each.value.probe.number_of_probes
  probe_threshold     = each.value.probe.probe_threshold
}

resource "azurerm_lb_rule" "this" {
  for_each = local.rules

  loadbalancer_id = azurerm_lb.this[each.value.lb_name].id

  name                           = each.value.rule_name
  protocol                       = each.value.rule.protocol
  frontend_port                  = each.value.rule.frontend_port
  backend_port                   = each.value.rule.backend_port
  frontend_ip_configuration_name = coalesce(each.value.rule.frontend_ip_configuration_name, local.default_frontend_name[each.value.lb_name])

  # Pools built here (by key) plus any raw ids passed in.
  backend_address_pool_ids = concat(
    [for key in each.value.rule.backend_pool_keys : azurerm_lb_backend_address_pool.this["${each.value.lb_name}/${key}"].id],
    each.value.rule.backend_address_pool_ids,
  )
  probe_id = each.value.rule.probe_key != null ? azurerm_lb_probe.this["${each.value.lb_name}/${each.value.rule.probe_key}"].id : each.value.rule.probe_id

  floating_ip_enabled     = each.value.rule.floating_ip_enabled
  tcp_reset_enabled       = each.value.rule.tcp_reset_enabled
  idle_timeout_in_minutes = each.value.rule.idle_timeout_in_minutes
  load_distribution       = each.value.rule.load_distribution
  disable_outbound_snat   = each.value.disable_outbound_snat
}

resource "azurerm_lb_outbound_rule" "this" {
  for_each = local.outbound_rules

  loadbalancer_id = azurerm_lb.this[each.value.lb_name].id

  name                    = each.value.rule_name
  protocol                = each.value.rule.protocol
  backend_address_pool_id = each.value.rule.backend_pool_key != null ? azurerm_lb_backend_address_pool.this["${each.value.lb_name}/${each.value.rule.backend_pool_key}"].id : each.value.rule.backend_address_pool_id

  dynamic "frontend_ip_configuration" {
    for_each = each.value.frontend_names

    content {
      name = frontend_ip_configuration.value
    }
  }

  allocated_outbound_ports = each.value.rule.allocated_outbound_ports
  idle_timeout_in_minutes  = each.value.rule.idle_timeout_in_minutes
  tcp_reset_enabled        = each.value.rule.tcp_reset_enabled
}

resource "azurerm_lb_nat_rule" "this" {
  for_each = local.nat_rules

  resource_group_name = local.resource_group_name
  loadbalancer_id     = azurerm_lb.this[each.value.lb_name].id

  name                           = each.value.rule_name
  protocol                       = each.value.rule.protocol
  backend_port                   = each.value.rule.backend_port
  frontend_ip_configuration_name = coalesce(each.value.rule.frontend_ip_configuration_name, local.default_frontend_name[each.value.lb_name])

  # Single-port NAT targets one machine; a port range fans out over a backend pool.
  frontend_port           = each.value.rule.frontend_port
  frontend_port_start     = each.value.rule.frontend_port_start
  frontend_port_end       = each.value.rule.frontend_port_end
  backend_address_pool_id = each.value.rule.backend_pool_key != null ? azurerm_lb_backend_address_pool.this["${each.value.lb_name}/${each.value.rule.backend_pool_key}"].id : each.value.rule.backend_address_pool_id

  floating_ip_enabled     = each.value.rule.floating_ip_enabled
  tcp_reset_enabled       = each.value.rule.tcp_reset_enabled
  idle_timeout_in_minutes = each.value.rule.idle_timeout_in_minutes
}

resource "azurerm_lb_nat_pool" "this" {
  for_each = local.nat_pools

  resource_group_name = local.resource_group_name
  loadbalancer_id     = azurerm_lb.this[each.value.lb_name].id

  name                           = each.value.pool_name
  protocol                       = each.value.pool.protocol
  frontend_port_start            = each.value.pool.frontend_port_start
  frontend_port_end              = each.value.pool.frontend_port_end
  backend_port                   = each.value.pool.backend_port
  frontend_ip_configuration_name = coalesce(each.value.pool.frontend_ip_configuration_name, local.default_frontend_name[each.value.lb_name])

  floating_ip_enabled     = each.value.pool.floating_ip_enabled
  tcp_reset_enabled       = each.value.pool.tcp_reset_enabled
  idle_timeout_in_minutes = each.value.pool.idle_timeout_in_minutes
}
