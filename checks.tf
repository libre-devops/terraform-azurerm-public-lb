# Post-plan sanity checks: informational (warn), they never fail an apply.

check "has_lbs" {
  assert {
    condition     = length(var.lbs) > 0
    error_message = "No load balancers are defined: the module call creates nothing."
  }
}

# A load-balancing rule without a health probe keeps sending traffic to dead backends. Probes are
# free; wire one up (probe_key or probe_id) for every rule.
check "rules_have_probes" {
  assert {
    condition = alltrue(flatten([
      for lb in values(var.lbs) : [
        for r in values(lb.rules) : r.probe_key != null || r.probe_id != null
      ]
    ]))
    error_message = "At least one load-balancing rule has no health probe, so unhealthy backends keep receiving traffic."
  }
}

# Implicit (default) outbound SNAT is on borrowed time in Azure and gives unpredictable port
# allocation. Prefer an explicit outbound_rules entry (or a NAT gateway on the subnet) for egress.
check "explicit_outbound" {
  assert {
    condition = alltrue([
      for lb in values(var.lbs) :
      length(lb.rules) == 0 || length(lb.outbound_rules) > 0 || alltrue([for r in values(lb.rules) : coalesce(r.disable_outbound_snat, false)])
    ])
    error_message = "At least one load balancer relies on implicit outbound SNAT: add an outbound_rules entry (or handle egress with a NAT gateway) and disable_outbound_snat on rules."
  }
}
