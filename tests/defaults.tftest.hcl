# Plan-time tests for the module. The provider is mocked, so no credentials, no features block,
# and no cloud calls are needed:
#   terraform init -backend=false && terraform test

mock_provider "azurerm" {}

variables {
  location          = "uksouth"
  resource_group_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-ldo-uks-tst-01"

  lbs = {
    "lbe-ldo-uks-tst-01" = {
      frontend_ip_configurations = {
        "public" = { public_ip_address_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-ldo-uks-tst-01/providers/Microsoft.Network/publicIPAddresses/pip-ldo-uks-tst-01" }
      }
      backend_pools = { "app" = {} }
      probes        = { "tcp-8443" = { port = 8443 } }
      rules = {
        "app-https" = {
          frontend_port     = 443
          backend_port      = 8443
          backend_pool_keys = ["app"]
          probe_key         = "tcp-8443"
        }
      }
      outbound_rules = {
        "egress" = { backend_pool_key = "app" }
      }
    }
  }
}

# Secure defaults: Standard SKU, and outbound rules flip disable_outbound_snat on for every rule.
run "creates_lb_with_defaults" {
  command = plan

  assert {
    condition     = azurerm_lb.this["lbe-ldo-uks-tst-01"].sku == "Standard"
    error_message = "The load balancer should default to the Standard SKU."
  }

  assert {
    condition     = azurerm_lb_rule.this["lbe-ldo-uks-tst-01/app-https"].disable_outbound_snat == true
    error_message = "Rules should default disable_outbound_snat to true when outbound rules exist."
  }

  assert {
    condition     = azurerm_lb_rule.this["lbe-ldo-uks-tst-01/app-https"].frontend_ip_configuration_name == "public"
    error_message = "A rule on a single-frontend load balancer should default to that frontend."
  }

  assert {
    condition     = azurerm_lb_outbound_rule.this["lbe-ldo-uks-tst-01/egress"].frontend_ip_configuration[0].name == "public"
    error_message = "An outbound rule should default to all of the load balancer's frontends."
  }

  assert {
    condition     = length(azurerm_lb_backend_address_pool.this) == 1 && length(azurerm_lb_probe.this) == 1 && length(azurerm_lb_outbound_rule.this) == 1
    error_message = "Each child map entry should create exactly one child resource."
  }
}

# Without outbound rules, disable_outbound_snat follows the caller (or stays off), and the
# explicit_outbound check flags the implicit-SNAT posture.
run "no_outbound_rules_keeps_snat_default" {
  command = plan

  expect_failures = [check.explicit_outbound]

  variables {
    lbs = {
      "lbe-ldo-uks-tst-01" = {
        frontend_ip_configurations = {
          "public" = { public_ip_address_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-ldo-uks-tst-01/providers/Microsoft.Network/publicIPAddresses/pip-ldo-uks-tst-01" }
        }
        backend_pools = { "app" = {} }
        probes        = { "tcp-8443" = { port = 8443 } }
        rules = {
          "app-https" = { frontend_port = 443, backend_port = 8443, backend_pool_keys = ["app"], probe_key = "tcp-8443" }
        }
      }
    }
  }

  assert {
    condition     = azurerm_lb_rule.this["lbe-ldo-uks-tst-01/app-https"].disable_outbound_snat == false
    error_message = "Without outbound rules, disable_outbound_snat should stay off unless the caller sets it."
  }
}

# The resource group is parsed from the id and exposed as an output.
run "parses_resource_group" {
  command = plan

  assert {
    condition     = output.resource_group_name == "rg-ldo-uks-tst-01"
    error_message = "resource_group_name should be parsed from resource_group_id."
  }
}

# Validation: Basic and Gateway SKUs are rejected here.
run "rejects_non_standard_sku" {
  command = plan

  variables {
    lbs = {
      "lbe-ldo-uks-tst-01" = {
        sku = "Gateway"
        frontend_ip_configurations = {
          "public" = { public_ip_address_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-ldo-uks-tst-01/providers/Microsoft.Network/publicIPAddresses/pip-ldo-uks-tst-01" }
        }
      }
    }
  }

  expect_failures = [var.lbs]
}

# Validation: a frontend must set exactly one of public ip or prefix.
run "rejects_frontend_with_both_references" {
  command = plan

  variables {
    lbs = {
      "lbe-ldo-uks-tst-01" = {
        frontend_ip_configurations = {
          "public" = {
            public_ip_address_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-ldo-uks-tst-01/providers/Microsoft.Network/publicIPAddresses/pip-ldo-uks-tst-01"
            public_ip_prefix_id  = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-ldo-uks-tst-01/providers/Microsoft.Network/publicIPPrefixes/ippre-ldo-uks-tst-01"
          }
        }
      }
    }
  }

  expect_failures = [var.lbs]
}

# Validation: HA-ports rules are internal-only, protocol All is rejected on rules here.
run "rejects_ha_ports_rule" {
  command = plan

  variables {
    lbs = {
      "lbe-ldo-uks-tst-01" = {
        frontend_ip_configurations = {
          "public" = { public_ip_address_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-ldo-uks-tst-01/providers/Microsoft.Network/publicIPAddresses/pip-ldo-uks-tst-01" }
        }
        rules = {
          "ha" = { protocol = "All", frontend_port = 0, backend_port = 0 }
        }
      }
    }
  }

  expect_failures = [var.lbs]
}

# Validation: an outbound rule must target a pool.
run "rejects_outbound_rule_without_pool" {
  command = plan

  variables {
    lbs = {
      "lbe-ldo-uks-tst-01" = {
        frontend_ip_configurations = {
          "public" = { public_ip_address_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-ldo-uks-tst-01/providers/Microsoft.Network/publicIPAddresses/pip-ldo-uks-tst-01" }
        }
        outbound_rules = {
          "egress" = {}
        }
      }
    }
  }

  expect_failures = [var.lbs]
}
