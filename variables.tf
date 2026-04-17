variable "region" {
  description = "Azure region where resources will be deployed"
  type        = string
  default     = "eastus"
}

variable "resource_name" {
  description = "Base name for resources"
  type        = string
  default     = "moodle-lab-rg"
}

variable "ssh_public_key" {
  description = "Path to the SSH public key"
  type        = string
  sensitive   = true
}

variable "vm_name" {
  description = "Name of the virtual machine"
  type        = string
  default     = "moodle-lab-vm"
}

variable "vm_size" {
  description = "Size of the virtual machine"
  type        = string
  default     = "Standard_B1ms"
}

variable "duckdns_domain" {
  description = "DuckDNS domain for dynamic DNS"
  type        = string
  default     = "moodlelab"
}

variable "duckdns_token" {
  description = "DuckDNS token for updating DNS records"
  type        = string
  sensitive   = true
}

variable "use_snapshots" {
  description = "Whether to use snapshots for backup"
  type        = bool
  default     = false
}