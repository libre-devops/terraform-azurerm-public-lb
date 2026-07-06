output "backend_pool_ids" {
  description = "Backend pool ids keyed by \"<lb>/<pool>\"."
  value       = module.public_lb.backend_pool_ids
}

output "frontend_ip_configurations" {
  description = "Frontend configurations as returned by Azure."
  value       = module.public_lb.frontend_ip_configurations
}

output "lb_ids" {
  description = "Map of load balancer name to resource id."
  value       = module.public_lb.ids
}

output "outbound_rule_ids" {
  description = "Outbound rule ids keyed by \"<lb>/<rule>\"."
  value       = module.public_lb.outbound_rule_ids
}

output "public_ip_address" {
  description = "The public ip the load balancer fronts."
  value       = module.public_ip.public_ip_addresses
}
