# ═══════════════════════════════════════════════════════════════
# PetClinic K8s Infrastructure - Simplified (No IAM/Monitoring)
# ═══════════════════════════════════════════════════════════════

# Generate SSH key pair for instances
resource "tls_private_key" "k8s_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "k8s_key" {
  key_name   = "${var.project_name}-${var.environment}-key"
  public_key = tls_private_key.k8s_key.public_key_openssh
}

# Save private key locally (since we can't use Secrets Manager)
resource "local_file" "private_key" {
  content         = tls_private_key.k8s_key.private_key_pem
  filename        = "${path.module}/${var.project_name}-${var.environment}-key.pem"
  file_permission = "0400"
}

# VPC Module
module "vpc" {
  source = "./modules/vpc"
  
  project_name       = var.project_name
  environment        = var.environment
  vpc_cidr           = var.vpc_cidr
  availability_zones = var.availability_zones
  
  enable_flow_logs = false  # تعطيل Flow Logs (يحتاج CloudWatch)
}

# Security Groups Module
module "security_groups" {
  source = "./modules/security-groups"
  
  project_name     = var.project_name
  environment      = var.environment
  vpc_id           = module.vpc.vpc_id
  vpc_cidr         = var.vpc_cidr
  allowed_ssh_cidr = var.allowed_ssh_cidr
}

# Bastion Host Module (بدون IAM Role)
module "bastion" {
  source = "./modules/bastion"
  
  project_name       = var.project_name
  environment        = var.environment
  subnet_id          = module.vpc.public_subnets[0]
  security_group_ids = [module.security_groups.bastion_sg_id]
  instance_type      = var.instance_type_bastion
  key_name           = aws_key_pair.k8s_key.key_name
  
  # لا نمرر IAM instance profile
}

# Master Nodes Module (بدون IAM Role)
module "master_nodes" {
  source = "./modules/master-nodes"
  
  project_name       = var.project_name
  environment        = var.environment
  master_count       = var.master_count
  subnet_ids         = module.vpc.private_subnets
  security_group_ids = [module.security_groups.master_sg_id]
  instance_type      = var.instance_type_master
  key_name           = aws_key_pair.k8s_key.key_name
  target_group_arn   = module.load_balancer.master_target_group_arn
  
  # لا نمرر IAM instance profile
}

# Worker Nodes Module (بدون IAM Role)
module "worker_nodes" {
  source = "./modules/worker-nodes"
  
  project_name       = var.project_name
  environment        = var.environment
  worker_count       = var.worker_count
  subnet_ids         = module.vpc.private_subnets
  security_group_ids = [module.security_groups.worker_sg_id]
  instance_type      = var.instance_type_worker
  key_name           = aws_key_pair.k8s_key.key_name
  
  # لا نمرر IAM instance profile
}

# Load Balancer Module
module "load_balancer" {
  source = "./modules/load-balancer"
  
  project_name       = var.project_name
  environment        = var.environment
  vpc_id             = module.vpc.vpc_id
  subnet_ids         = module.vpc.private_subnets
  security_group_ids = [module.security_groups.lb_sg_id]
}

module "simple_s3" {
  source      = "./modules/s3"
  bucket_name = var.bucket_name
  region      = var.aws_region
}

