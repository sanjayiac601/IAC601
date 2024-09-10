# Configure the Azure provider
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "=4.1.0"
    }
  }
}

provider "azurerm" {
  features {}
  subscription_id = "164a31e8-3030-46ef-b505-36be4f159d30"
}

# Resource group
resource "azurerm_resource_group" "rg" {
  name     = var.rg_name
  location = "AustraliaEast"
}

# Network
resource "azurerm_virtual_network" "vnet" {
  name                = var.vnet_name
  address_space       = ["10.20.0.0/16"]
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

# VM Subnet
resource "azurerm_subnet" "subnet-vm" {
  name                 = "SanjyaIac-subnet1"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.20.1.0/24"]
}

# Public IP
resource "azurerm_public_ip" "public_ip" {
  name                = var.public_ip
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

# Network security group 
resource "azurerm_network_security_group" "nsg" {
  name                = var.nsg_name
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  security_rule {
    name                       = "RDP"
    priority                   = 1000
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3389"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "HTTP"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

# Network interface card
resource "azurerm_network_interface" "nic" {
  name                = "SanjayaIac-nic"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "my_nic_configuration"
    subnet_id                     = azurerm_subnet.subnet-vm.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.public_ip.id
  }

  tags = {
    environment = "dev"
  }
}

# Virtual machine
resource "azurerm_windows_virtual_machine" "vm" {
  name                  = "SanjayIac-vm"
  location              = azurerm_resource_group.rg.location
  resource_group_name   = azurerm_resource_group.rg.name
  network_interface_ids = [azurerm_network_interface.nic.id]
  size                  = "Standard_B1ms"

  os_disk {
    name                 = "myOsDisk"
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2022-datacenter-azure-edition"
    version   = "latest"
  }

  admin_username = "azureuser"
  admin_password = "Aspire@2023"

  tags = {
    environment = "dev"
  }
}

# Database Subnet
resource "azurerm_subnet" "subnet-db" {
  name                 = "${var.vnet_name}-db-subnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.20.2.0/24"]
  service_endpoints    = ["Microsoft.Storage"]
  delegation {
    name = "fs"
    service_delegation {
      name = "Microsoft.DBforMySQL/flexibleServers"
      actions = [
        "Microsoft.Network/virtualNetworks/subnets/join/action",
      ]
    }
  }
}

# Private DNS zone
resource "azurerm_private_dns_zone" "default" {
  name                = "sanjayiac.mysql.database.azure.com"
  resource_group_name = azurerm_resource_group.rg.name
}

# Private DNS zone Network Link
resource "azurerm_private_dns_zone_virtual_network_link" "default" {
  name                  = "mysqlfsVnetZonetest.com"
  private_dns_zone_name = azurerm_private_dns_zone.default.name
  resource_group_name   = azurerm_resource_group.rg.name
  virtual_network_id    = azurerm_virtual_network.vnet.id
  
  depends_on = [azurerm_private_dns_zone.default]
}

# Azure MySQL Flexible Server
resource "azurerm_mysql_flexible_server" "fs_server" {
  location                     = azurerm_resource_group.rg.location
  name                         = "sanjayiac-mysqlfs-iac601"
  resource_group_name          = azurerm_resource_group.rg.name
  administrator_login          = "sanjay"
  administrator_password       = "Aspire@2024"
  backup_retention_days        = 7
  delegated_subnet_id          = azurerm_subnet.subnet-db.id
  private_dns_zone_id          = azurerm_private_dns_zone.default.id
  sku_name                     = "GP_Standard_D2ds_v4"
  version                      = "8.0.21"
  zone                         = "1"

  high_availability {
    mode = "ZoneRedundant"
  }

  maintenance_window {
    day_of_week  = 0
    start_hour   = 8
    start_minute = 0
  }

  storage {
    iops    = 360
    size_gb = 20
  }

  depends_on = [azurerm_private_dns_zone_virtual_network_link.default]
}

# Database NSG Association
resource "azurerm_subnet_network_security_group_association" "flexi-server-nsg-association" {
  subnet_id                 = azurerm_subnet.subnet-db.id
  network_security_group_id = azurerm_network_security_group.nsg.id
}