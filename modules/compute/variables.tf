variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "owner" {
  type = string
}

variable "region" {
  type    = string
  default = "ap-south-1"
}

variable "instance_type" {
  type    = string
  default = "t3.medium"
}

variable "vpc_id" {
  type = string
}

variable "subnet_id" {
  type = string
}