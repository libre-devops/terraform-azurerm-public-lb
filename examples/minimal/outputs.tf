output "lb_ids" {
  description = "Map of load balancer name to resource id."
  value       = module.public_lb.ids
}

output "public_ip_address" {
  description = "The public ip the load balancer fronts."
  value       = module.public_ip.public_ip_addresses
}
