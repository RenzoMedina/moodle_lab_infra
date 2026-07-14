resource "azurerm_resource_group" "rg" {
  name     = var.resource_name
  location = var.region
}

resource "azurerm_virtual_network" "vnet" {
  name                = "moodle-lab-vnet"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_subnet" "subnet" {
  name                 = "moodle-lab-subnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.2.0/24"]
}

resource "azurerm_public_ip" "public-ip" {
  name                = "moodle-lab-public-ip"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags = {
    environment = "Development"
    project     = "MoodleLab"
  }
}

resource "azurerm_network_interface" "nic" {
  name                = "moodle-lab-nic"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "moodle-lab-nic-config"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.public-ip.id
  }
}

resource "azurerm_network_security_group" "nsg" {
  name                = "moodle-lab-nsg"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  security_rule {
    name                       = "Allow-SSH"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
  security_rule {
    name                       = "Allow-HTTP"
    priority                   = 1002
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
  security_rule {
    name                       = "Allow-HTTPS"
    priority                   = 1003
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_network_interface_security_group_association" "nsg_assoc" {
  network_interface_id      = azurerm_network_interface.nic.id
  network_security_group_id = azurerm_network_security_group.nsg.id
}

resource "azurerm_managed_disk" "from_snapshot" {
  count                = var.use_snapshots ? 1 : 0
  name                 = "moodle-lab-disk-restored"
  location             = azurerm_resource_group.rg.location
  resource_group_name  = azurerm_resource_group.rg.name
  storage_account_type = "Standard_LRS"
  os_type              = "Linux"
  create_option        = "Copy"
  source_resource_id   = var.snapshot_id
}

resource "time_sleep" "wait_after_disk_create" {
  count            = var.use_snapshots ? 1 : 0
  depends_on       = [azurerm_managed_disk.from_snapshot]
  destroy_duration = "30s"
}

resource "azurerm_virtual_machine" "vm_from_snapshot" {
  count               = var.use_snapshots ? 1 : 0
  name                = var.vm_name
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  network_interface_ids = [
    azurerm_network_interface.nic.id
  ]
  vm_size = var.vm_size

  delete_os_disk_on_termination    = true
  delete_data_disks_on_termination = true

  storage_os_disk {
    name            = azurerm_managed_disk.from_snapshot[0].name
    managed_disk_id = azurerm_managed_disk.from_snapshot[0].id
    create_option   = "Attach"
    os_type         = "Linux"
  }

  depends_on = [time_sleep.wait_after_disk_create]

  lifecycle {
    replace_triggered_by = [
      azurerm_managed_disk.from_snapshot[0].id
    ]
  }

  tags = {
    environment = "staging"
    project     = "MoodleLab"
  }
}

resource "azurerm_linux_virtual_machine" "vm" {
  count               = var.use_snapshots ? 0 : 1
  name                = var.vm_name
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  size                = var.vm_size
  admin_username      = "adminuser"
  network_interface_ids = [
    azurerm_network_interface.nic.id,
  ]

  admin_ssh_key {
    username   = "adminuser"
    public_key = var.ssh_public_key
  }

  os_disk {
    name                 = "moodle-lab-disk"
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }
  custom_data = base64encode(templatefile("${path.module}/cloud-init.yml", {
    duckdns_domain     = var.duckdns_domain
    duckdns_token      = var.duckdns_token
    moodle_branch      = var.moodle_branch
    moodle_db_name     = var.moodle_db_name
    moodle_db_user     = var.moodle_db_user
    moodle_db_password = var.moodle_db_password
  }))

  tags = {
    environment = "staging"
    project     = "MoodleLab"
  }
}