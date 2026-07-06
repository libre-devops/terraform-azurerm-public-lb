locals {
  location = lookup(var.regions, var.loc, "uksouth")
  rg_name  = "rg-${var.short}-${var.loc}-${terraform.workspace}-001"
  pip_name = "pip-${var.short}-${var.loc}-${terraform.workspace}-001"
  lb_name  = "lbe-${var.short}-${var.loc}-${terraform.workspace}-001"
}

module "tags" {
  source  = "libre-devops/tags/azurerm"
  version = "~> 4.0"

  cost_centre     = "1888/67"
  owner           = "platform@example.com"
  deployed_branch = var.deployed_branch
  deployed_repo   = var.deployed_repo
}

module "rg" {
  source  = "libre-devops/rg/azurerm"
  version = "~> 4.0"

  resource_groups = [{ name = local.rg_name, location = local.location, tags = module.tags.tags }]
}

module "public_ip" {
  source  = "libre-devops/public-ip/azurerm"
  version = "~> 4.0"

  resource_group_id = module.rg.ids[local.rg_name]
  location          = local.location
  tags              = module.tags.tags

  public_ips = {
    (local.pip_name) = { zones = ["1", "2", "3"] }
  }
}

# Minimal call: one public load balancer on a zone-redundant public ip, with a backend pool, a Tcp
# health probe, and a load-balancing rule. Egress is left to an outbound rule or NAT gateway, so
# the rule opts out of implicit SNAT.
module "public_lb" {
  source = "../../"

  resource_group_id = module.rg.ids[local.rg_name]
  location          = local.location
  tags              = module.tags.tags

  lbs = {
    (local.lb_name) = {
      frontend_ip_configurations = {
        "public" = { public_ip_address_id = module.public_ip.public_ip_ids[local.pip_name] }
      }

      backend_pools = { "app" = {} }

      probes = {
        "tcp-8443" = { port = 8443 }
      }

      rules = {
        "app-https" = {
          frontend_port         = 443
          backend_port          = 8443
          backend_pool_keys     = ["app"]
          probe_key             = "tcp-8443"
          disable_outbound_snat = true
        }
      }
    }
  }
}
