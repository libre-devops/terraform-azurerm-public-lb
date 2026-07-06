variable "lbs" {
  description = <<-EOT
    Public (internet-facing) load balancers to create, keyed by load balancer name. Every frontend
    references a public ip or public ip prefix created elsewhere (compose the public-ip module);
    use the private-lb module for internal frontends. Fields:
      sku        Standard only: Basic is retired and rejected, and the Gateway SKU is
                 private-frontend only, so it lives in the private-lb module.
      sku_tier   Regional (default) or Global. Global is the cross-region load balancer: its
                 backend pool addresses reference regional load balancer frontends via
                 backend_address_ip_configuration_id.
      edge_zone  Edge Zone the load balancer lives in.
      tags       Per-load-balancer tags (falls back to the module tags when null).
      frontend_ip_configurations  Public frontends keyed by frontend name: exactly one of
                 public_ip_address_id or public_ip_prefix_id. Zone redundancy rides on the public
                 ip itself, not the frontend.
      backend_pools  Backend address pools keyed by pool name. virtual_network_id enables
                 IP-based backends (with optional synchronous_mode); addresses is a map of
                 IP-based backend addresses keyed by address name (on a Global tier balancer,
                 addresses point at regional frontends via backend_address_ip_configuration_id).
      probes     Health probes keyed by probe name. protocol defaults to Tcp; Http and Https
                 require request_path.
      rules      Load-balancing rules keyed by rule name. Reference module-built objects by key
                 (backend_pool_keys, probe_key) or pass raw ids (backend_address_pool_ids,
                 probe_id). frontend_ip_configuration_name may be omitted when the load balancer
                 has exactly one frontend. When the load balancer defines outbound_rules,
                 disable_outbound_snat defaults to true on every rule (required by Azure when
                 inbound and outbound rules share a pool, and the explicit-outbound posture).
      outbound_rules  Outbound SNAT rules keyed by rule name: the explicit, recommended way to
                 give backends internet egress. backend_pool_key or backend_address_pool_id picks
                 the pool; frontend_ip_configuration_names picks the frontends (defaults to all of
                 the load balancer's frontends); allocated_outbound_ports tunes SNAT port
                 allocation.
      nat_rules  Inbound NAT rules keyed by rule name: either a single frontend_port, or a
                 frontend_port_start/frontend_port_end range targeting a backend pool (by
                 backend_pool_key or backend_address_pool_id).
      nat_pools  Legacy inbound NAT pools keyed by pool name (superseded by port-range NAT rules;
                 kept for VMSS setups that still need them).
  EOT
  type = map(object({
    sku       = optional(string, "Standard")
    sku_tier  = optional(string, "Regional")
    edge_zone = optional(string)
    tags      = optional(map(string))

    frontend_ip_configurations = map(object({
      public_ip_address_id = optional(string)
      public_ip_prefix_id  = optional(string)
    }))

    backend_pools = optional(map(object({
      virtual_network_id = optional(string)
      synchronous_mode   = optional(string)
      addresses = optional(map(object({
        virtual_network_id                  = optional(string)
        ip_address                          = optional(string)
        backend_address_ip_configuration_id = optional(string)
      })), {})
    })), {})

    probes = optional(map(object({
      protocol            = optional(string, "Tcp")
      port                = number
      request_path        = optional(string)
      interval_in_seconds = optional(number)
      number_of_probes    = optional(number)
      probe_threshold     = optional(number)
    })), {})

    rules = optional(map(object({
      protocol                       = optional(string, "Tcp")
      frontend_port                  = number
      backend_port                   = number
      frontend_ip_configuration_name = optional(string)
      backend_pool_keys              = optional(list(string), [])
      backend_address_pool_ids       = optional(list(string), [])
      probe_key                      = optional(string)
      probe_id                       = optional(string)
      floating_ip_enabled            = optional(bool)
      tcp_reset_enabled              = optional(bool)
      idle_timeout_in_minutes        = optional(number)
      load_distribution              = optional(string)
      disable_outbound_snat          = optional(bool)
    })), {})

    outbound_rules = optional(map(object({
      protocol                        = optional(string, "All")
      backend_pool_key                = optional(string)
      backend_address_pool_id         = optional(string)
      frontend_ip_configuration_names = optional(list(string))
      allocated_outbound_ports        = optional(number)
      idle_timeout_in_minutes         = optional(number)
      tcp_reset_enabled               = optional(bool)
    })), {})

    nat_rules = optional(map(object({
      protocol                       = optional(string, "Tcp")
      backend_port                   = number
      frontend_port                  = optional(number)
      frontend_port_start            = optional(number)
      frontend_port_end              = optional(number)
      backend_pool_key               = optional(string)
      backend_address_pool_id        = optional(string)
      frontend_ip_configuration_name = optional(string)
      floating_ip_enabled            = optional(bool)
      tcp_reset_enabled              = optional(bool)
      idle_timeout_in_minutes        = optional(number)
    })), {})

    nat_pools = optional(map(object({
      protocol                       = optional(string, "Tcp")
      frontend_port_start            = number
      frontend_port_end              = number
      backend_port                   = number
      frontend_ip_configuration_name = optional(string)
      floating_ip_enabled            = optional(bool)
      tcp_reset_enabled              = optional(bool)
      idle_timeout_in_minutes        = optional(number)
    })), {})
  }))
  default = {}

  validation {
    condition     = alltrue([for lb in values(var.lbs) : lb.sku == "Standard"])
    error_message = "sku must be Standard: Basic load balancers are retired (30 September 2025), and the Gateway SKU only takes private frontends (use the private-lb module)."
  }

  validation {
    condition     = alltrue([for lb in values(var.lbs) : contains(["Regional", "Global"], lb.sku_tier)])
    error_message = "sku_tier must be Regional or Global."
  }

  validation {
    condition     = alltrue([for lb in values(var.lbs) : length(lb.frontend_ip_configurations) > 0])
    error_message = "Every load balancer needs at least one frontend_ip_configuration."
  }

  validation {
    condition = alltrue(flatten([
      for lb in values(var.lbs) : [
        for f in values(lb.frontend_ip_configurations) :
        (f.public_ip_address_id != null && f.public_ip_prefix_id == null) || (f.public_ip_address_id == null && f.public_ip_prefix_id != null)
      ]
    ]))
    error_message = "every frontend sets exactly one of public_ip_address_id or public_ip_prefix_id."
  }

  validation {
    condition = alltrue(flatten([
      for lb in values(var.lbs) : [
        for p in values(lb.backend_pools) : p.synchronous_mode == null ? true : p.virtual_network_id != null
      ]
    ]))
    error_message = "backend pool synchronous_mode requires virtual_network_id to be set on the pool."
  }

  validation {
    condition = alltrue(flatten([
      for lb in values(var.lbs) : [
        for p in values(lb.backend_pools) :
        p.virtual_network_id == null ? true : alltrue([for a in values(p.addresses) : a.virtual_network_id == null])
      ]
    ]))
    error_message = "Azure rejects a virtual network on both the pool and its addresses (IpBasedLbShouldHaveVnetPropertyEitherOnPoolOrBackendAddressLevel): set virtual_network_id on the pool or on each address, never both."
  }

  validation {
    condition = alltrue(flatten([
      for lb in values(var.lbs) : [
        for pr in values(lb.probes) : contains(["Tcp", "Http", "Https"], pr.protocol)
      ]
    ]))
    error_message = "probe protocol must be Tcp, Http, or Https."
  }

  validation {
    condition = alltrue(flatten([
      for lb in values(var.lbs) : [
        for pr in values(lb.probes) : pr.protocol == "Tcp" ? true : pr.request_path != null
      ]
    ]))
    error_message = "Http and Https probes require request_path."
  }

  validation {
    condition = alltrue(flatten([
      for lb in values(var.lbs) : [
        for r in values(lb.rules) : contains(["Tcp", "Udp"], r.protocol)
      ]
    ]))
    error_message = "rule protocol must be Tcp or Udp: HA-ports rules (protocol All) are internal-load-balancer only, use the private-lb module."
  }

  validation {
    condition = alltrue(flatten([
      for lb in values(var.lbs) : [
        for r in values(lb.rules) : [
          for key in r.backend_pool_keys : contains(keys(lb.backend_pools), key)
        ]
      ]
    ]))
    error_message = "every rule backend_pool_keys entry must match a key in the load balancer's backend_pools."
  }

  validation {
    condition = alltrue(flatten([
      for lb in values(var.lbs) : [
        for r in values(lb.rules) : r.probe_key == null ? true : contains(keys(lb.probes), r.probe_key)
      ]
    ]))
    error_message = "every rule probe_key must match a key in the load balancer's probes."
  }

  validation {
    condition = alltrue(flatten([
      for lb in values(var.lbs) : [
        for r in concat(values(lb.rules), values(lb.nat_rules), values(lb.nat_pools)) :
        r.frontend_ip_configuration_name == null ? length(lb.frontend_ip_configurations) == 1 : contains(keys(lb.frontend_ip_configurations), r.frontend_ip_configuration_name)
      ]
    ]))
    error_message = "frontend_ip_configuration_name must name a frontend key, and may only be omitted when the load balancer has exactly one frontend."
  }

  validation {
    condition = alltrue(flatten([
      for lb in values(var.lbs) : [
        for o in values(lb.outbound_rules) : contains(["Tcp", "Udp", "All"], o.protocol)
      ]
    ]))
    error_message = "outbound rule protocol must be Tcp, Udp, or All."
  }

  validation {
    condition = alltrue(flatten([
      for lb in values(var.lbs) : [
        for o in values(lb.outbound_rules) :
        (o.backend_pool_key != null || o.backend_address_pool_id != null) && (o.backend_pool_key == null ? true : contains(keys(lb.backend_pools), o.backend_pool_key))
      ]
    ]))
    error_message = "every outbound rule needs a backend pool, by backend_pool_key (matching a backend_pools key) or backend_address_pool_id."
  }

  validation {
    condition = alltrue(flatten([
      for lb in values(var.lbs) : [
        for o in values(lb.outbound_rules) : o.frontend_ip_configuration_names == null ? true : alltrue([
          for fname in o.frontend_ip_configuration_names : contains(keys(lb.frontend_ip_configurations), fname)
        ])
      ]
    ]))
    error_message = "every outbound rule frontend_ip_configuration_names entry must match a frontend key."
  }

  validation {
    condition = alltrue(flatten([
      for lb in values(var.lbs) : [
        for nr in values(lb.nat_rules) :
        (nr.frontend_port != null && nr.frontend_port_start == null && nr.frontend_port_end == null && nr.backend_pool_key == null && nr.backend_address_pool_id == null) ||
        (nr.frontend_port == null && nr.frontend_port_start != null && nr.frontend_port_end != null && (nr.backend_pool_key != null || nr.backend_address_pool_id != null))
      ]
    ]))
    error_message = "a NAT rule is either single-port (frontend_port only) or a port range (frontend_port_start and frontend_port_end plus a backend pool via backend_pool_key or backend_address_pool_id)."
  }

  validation {
    condition = alltrue(flatten([
      for lb in values(var.lbs) : [
        for nr in values(lb.nat_rules) : nr.backend_pool_key == null ? true : contains(keys(lb.backend_pools), nr.backend_pool_key)
      ]
    ]))
    error_message = "every NAT rule backend_pool_key must match a key in the load balancer's backend_pools."
  }
}

variable "location" {
  description = "Azure region for the load balancers."
  type        = string
}

variable "resource_group_id" {
  description = "Resource id of the resource group the load balancers are created in. The resource group name and subscription are parsed from this id."
  type        = string

  validation {
    condition     = try(provider::azurerm::parse_resource_id(var.resource_group_id).resource_type, "") == "resourceGroups"
    error_message = "resource_group_id must be a resource group resource id."
  }
}

variable "tags" {
  description = "Tags applied to the load balancers (unless a load balancer sets its own)."
  type        = map(string)
  default     = {}
}
