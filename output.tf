output "my_ip_public" {
  value = azurerm_public_ip.public-ip.ip_address
  description = "Ip address of the virtual machine use DuckDNS to access it with a domain name"
}

output "ssh_command" {
  value = "ssh adminuser@${azurerm_public_ip.public-ip.ip_address}"
  description = "SSH command to connect to the virtual machine"
}