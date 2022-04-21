variable "rg_name" {
  description = "The name of the resource group, this module does not create a resource group, it is expecting the value of a resource group already exists"
  type        = string
  validation {
    condition     = length(var.rg_name) > 1 && length(var.rg_name) <= 24
    error_message = "Resource group name is not valid."
  }
}

variable "location" {
  description = "The location for this resource to be put in"
  type        = string
}

variable "lb_name" {
  description = "The hostname of the vm"
  type        = string
}

variable "lb_sku_name" {
  description = "The SKU of the lb"
  type        = string
  default     = "Standard"
}

variable "lb_ip_configuration_name" {
  description = "The name of the frontend IP Configuration name"
  type        = string
}

variable "lb_bpool_name" {
  description = "The name for the backend pool for the Load Balancer"
  type        = string
}

variable "enable_outbound_rule" {
  description = "Whether an outbound nat rule should be made"
  type        = bool
}

variable "outbound_rule_name" {
  description = "The name of the outbound nat rule"
  type        = string
}

variable "outbound_protocol" {
  type        = string
  description = "The protocol for the outbound NAT rule"
}

variable "allocated_outbound_ports" {
  description = "The number of ports allocated for the outbound rule"
  type        = number
}

variable "pip_sku" {
  default     = null
  description = "If you wish to assign a public IP directly to your nic, set this to Standard"
  type        = string
}

variable "pip_name" {
  default     = null
  description = "If you are using a Public IP, set the name in this variable"
  type        = string
}

variable "pip_custom_dns_label" {
  default     = null
  description = "If you are using a public IP and wish to assign a custom DNS label, set here, otherwise, the VM host name will be used"
}

variable "availability_zone" {
  description = "The availability zone for the LB and PIP to be created to"
  type        = list(any)
}

variable "tags" {
  type        = map(string)
  description = "A map of the tags to use on the resources that are deployed with this module."

  default = {
    source = "terraform"
  }
}

variable "allocation_method" {
  description = "Defines how an IP address is assigned. Options are Static or Dynamic."
  type        = string
  default     = "Dynamic"
}

variable "identity_type" {
  description = "The Managed Service Identity Type of this Virtual Machine."
  type        = string
  default     = ""
}

variable "identity_ids" {
  description = "Specifies a list of user managed identity ids to be assigned to the VM."
  type        = list(string)
  default     = []
}
