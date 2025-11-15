# Production Environment Configuration
aws_region  = "us-east-1"
environment = "prod"
owner       = "DevOps-Team"
project_name = "petclinic"

# Network
vpc_cidr           = "10.2.0.0/16"
availability_zones = ["us-east-1a", "us-east-1b", "us-east-1c"]

# Cluster sizing - full scale for production
master_count = 3
worker_count = 6  # Maximum workers for production workload

# Instance types - performance-optimized for production
instance_type_bastion = "t3.medium"
instance_type_master  = "t3.xlarge"
instance_type_worker  = "t3.xlarge"

# Security
allowed_ssh_cidr = "YOUR_OFFICE_IP/32"  # IMPORTANT: Restrict to your corporate IP range

# Monitoring
enable_monitoring = true