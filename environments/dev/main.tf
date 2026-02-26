module "networking" {
  source = "../../modules/networking"

  project_name      = var.project_name
  environment       = var.environment
  owner             = var.owner
  instance_tenancy  = var.instance_tenancy
  cidr_block        = var.cidr_block
  subnet_cidr_block = var.subnet_cidr_block
  availability_zone = var.availability_zone
  enable_flow_logs       = true
  flow_log_retention_days = 1
}

module "compute" {
  source = "../../modules/compute"

  project_name = var.project_name
  environment  = var.environment
  owner        = var.owner

  instance_type = var.instance_type

  vpc_id    = module.networking.vpc_id
  subnet_id = module.networking.public_subnet_id
}
