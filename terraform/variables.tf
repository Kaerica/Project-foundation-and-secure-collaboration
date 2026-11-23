variable "subscription_id" {
  description = "Azure subscription ID"
  type        = string
}

variable "location" {
  description = "Azure region"
  type        = string
  default     = "westeurope"
}

variable "environment" {
  description = "Deployment environment"
  type        = string
  default     = "dev"
}

variable "vm_size" {
  description = "Azure VM size"
  type        = string
  default     = "Standard_B1s"
}

variable "admin_username" {
  description = "Linux VM administrator username"
  type        = string
}

variable "ssh_public_key" {
  description = "SSH public key"
  type        = string
}

variable "postgresql_server_name" {
  description = "Globally unique name for the Azure Database for PostgreSQL server"
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9]([a-z0-9-]{1,61}[a-z0-9])$", var.postgresql_server_name))
    error_message = "The PostgreSQL server name must be 3-63 lowercase letters, numbers, or hyphens, and start and end with a letter or number."
  }
}

variable "postgresql_admin_username" {
  description = "Administrator login for the PostgreSQL server"
  type        = string

  validation {
    condition     = can(regex("^[A-Za-z][A-Za-z0-9_]{0,62}$", var.postgresql_admin_username))
    error_message = "The PostgreSQL administrator login must start with a letter and contain only letters, numbers, or underscores."
  }
}

variable "postgresql_admin_password" {
  description = "Administrator password for the PostgreSQL server"
  type        = string
  sensitive   = true
}

variable "postgresql_database_name" {
  description = "Database created for the Inventory Manager"
  type        = string
  default     = "inventory_manager"

  validation {
    condition     = can(regex("^[A-Za-z_][A-Za-z0-9_-]{0,62}$", var.postgresql_database_name))
    error_message = "The PostgreSQL database name must start with a letter or underscore and contain only letters, numbers, underscores, or hyphens."
  }
}

variable "postgresql_app_username" {
  description = "Least-privilege application login for PostgreSQL"
  type        = string
  default     = "inventory_app"

  validation {
    condition     = can(regex("^[A-Za-z][A-Za-z0-9_]{0,62}$", var.postgresql_app_username))
    error_message = "The PostgreSQL application login must start with a letter and contain only letters, numbers, or underscores."
  }
}

variable "postgresql_app_password" {
  description = "Password for the application PostgreSQL login"
  type        = string
  sensitive   = true
}

variable "container_registry_name" {
  description = "Globally unique alphanumeric name for Azure Container Registry"
  type        = string

  validation {
    condition     = can(regex("^[A-Za-z0-9]{5,50}$", var.container_registry_name))
    error_message = "The container registry name must be 5-50 alphanumeric characters with no hyphens."
  }
}

variable "container_image_tag" {
  description = "Initial/bootstrap tag for the Inventory Manager image pulled by the VM; CD deployments pass an explicit Git SHA tag through Ansible"
  type        = string
  default     = "latest"

  validation {
    condition     = can(regex("^[A-Za-z0-9_][A-Za-z0-9_.-]{0,127}$", var.container_image_tag))
    error_message = "The container image tag must be 1-128 characters and use Docker tag characters."
  }
}