variable "location" {
  description = "The Azure region where resources will be created."
  type        = string
  default     = "canadacentral"
}

variable "resource_group_name" {
  description = "The name of the resource group for the application infrastructure."
  type        = string
  default     = "hich0005-a12-rg"
}
