# Development Environment Configuration
aws_region  = "us-east-1"
environment = "dev"
owner       = "DevOps-Team"
project_name = "petclinic"

# Network
vpc_cidr           = "10.0.0.0/16"
availability_zones = ["us-east-1a", "us-east-1b", "us-east-1c"]

# Cluster sizing - smaller for dev
master_count = 3
worker_count = 3

# Instance types - cost-optimized for dev
instance_type_bastion = "t3.small"
instance_type_master  = "t3.medium"
instance_type_worker  = "t3.medium"

# Security
allowed_ssh_cidr = "0.0.0.0/0"  # Restrict to your IP in production

# Monitoring
enable_monitoring = true