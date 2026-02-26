variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "owner" {
  type = string
}

variable "cidr_block" {
  description = "VPC CIDR block"
  type        = string
}

variable "instance_tenancy" {
  description = "VPC instance tenancy"
  type        = string
  default     = "default"
}

variable "subnet_cidr_block" {
  description = "Subnet CIDR block" #"10.0.1.0/24"
  type        = string
}

variable "availability_zone" {
  description = "Availability Zone for the subnet" #"ap-south-1a"
  type        = string
}

#Control flow logs variable
variable "enable_flow_logs" {
  description = "Enable VPC flow logs"
  type        = bool
  default     = true
}

variable "flow_log_retention_days" {
  description = "Retention days for VPC flow logs"
  type        = number
  default     = 7
}

