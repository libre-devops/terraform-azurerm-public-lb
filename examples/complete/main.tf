locals {
  location   = lookup(var.regions, var.loc, "uksouth")
  rg_name    = "rg-${var.short}-${var.loc}-${terraform.workspace}-002"
  pip_name   = "pip-${var.short}-${var.loc}-${terraform.workspace}-002"
  ippre_name = "ippre-${var.short}-${var.loc}-${terraform.workspace}-002"
  lb_name    = "lbe-${var.short}-${var.loc}-${terraform.workspace}-002"
}

module "tags" {
  source  = "libre-devops/tags/azurerm"
  version = "~> 4.0"

  cost_centre     = "1888/67"
  owner           = "platform@example.com"
  deployed_branch = var.deployed_branch
  deployed_repo   = var.deployed_repo
  additional_tags = { Application = "terraform-azurerm-public-lb" }
}

module "rg" {
  source  = "libre-devops/rg/azurerm"
  version = "~> 4.0"

  resource_groups = [{ name = local.rg_name, location = local.location, tags = module.tags.tags }]
}

# A zone-redundant public ip for inbound, and a /31 prefix dedicated to outbound SNAT.
module "public_ip" {
  source  = "libre-devops/public-ip/azurerm"
  version = "~> 4.0"

  resource_group_id = module.rg.ids[local.rg_name]
  location          = local.location
  tags              = module.tags.tags

  public_ip_prefixes = {
    (local.ippre_name) = { prefix_length = 31, zones = ["1", "2", "3"] }
  }

  public_ips = {
    (local.pip_name) = { zones = ["1", "2", "3"] }
  }
}

# Complete call: every feature of the module on one public load balancer.
#
# - Two frontends: "inbound" on a public ip, "snat" on a public ip prefix (rules then name their
#   frontend, there is more than one).
# - Two backend pools, one vnet-agnostic and one carrying tuned SNAT egress.
# - Probes: a Tcp probe and an Http probe with a request path and tuned thresholds.
# - Rules: Https and Dns rules; disable_outbound_snat is defaulted to true by the module because
#   outbound rules exist.
# - Outbound: an explicit outbound rule over the "snat" frontend prefix with tuned port
#   allocation.
# - NAT: a single-port NAT rule, a port-range NAT rule fanning out over the "app" pool, and a
#   legacy NAT pool for VMSS-style setups.
module "public_lb" {
  source = "../../"

  resource_group_id = module.rg.ids[local.rg_name]
  location          = local.location
  tags              = module.tags.tags

  lbs = {
    (local.lb_name) = {
      frontend_ip_configurations = {
        "inbound" = { public_ip_address_id = module.public_ip.public_ip_ids[local.pip_name] }
        "snat"    = { public_ip_prefix_id = module.public_ip.public_ip_prefix_ids[local.ippre_name] }
      }

      backend_pools = {
        "app" = {}
        "dns" = {}
      }

      probes = {
        "tcp-8443" = { port = 8443 }
        "http-health" = {
          protocol            = "Http"
          port                = 8080
          request_path        = "/healthz"
          interval_in_seconds = 15
          probe_threshold     = 2
        }
      }

      rules = {
        "app-https" = {
          frontend_ip_configuration_name = "inbound"
          frontend_port                  = 443
          backend_port                   = 8443
          backend_pool_keys              = ["app"]
          probe_key                      = "http-health"
          load_distribution              = "SourceIPProtocol"
          idle_timeout_in_minutes        = 15
          tcp_reset_enabled              = true
        }
        "dns-udp" = {
          frontend_ip_configuration_name = "inbound"
          protocol                       = "Udp"
          frontend_port                  = 53
          backend_port                   = 53
          backend_pool_keys              = ["dns"]
          probe_key                      = "tcp-8443"
        }
      }

      outbound_rules = {
        "egress" = {
          backend_pool_key                = "app"
          frontend_ip_configuration_names = ["snat"]
          allocated_outbound_ports        = 4096
          idle_timeout_in_minutes         = 15
          tcp_reset_enabled               = true
        }
      }

      nat_rules = {
        "rule-ssh-admin" = {
          frontend_ip_configuration_name = "inbound"
          frontend_port                  = 2222
          backend_port                   = 22
        }
        "rule-ssh-fleet" = {
          frontend_ip_configuration_name = "inbound"
          frontend_port_start            = 50000
          frontend_port_end              = 50019
          backend_port                   = 22
          backend_pool_key               = "app"
        }
      }

      nat_pools = {
        "rdp-vmss" = {
          frontend_ip_configuration_name = "inbound"
          frontend_port_start            = 51000
          frontend_port_end              = 51019
          backend_port                   = 3389
        }
      }
    }
  }
}
