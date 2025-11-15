# Test Environment Configuration
aws_region  = "us-east-1"
environment = "test"
owner       = "DevOps-Team"
project_name = "petclinic"

# Network
vpc_cidr           = "10.1.0.0/16"
availability_zones = ["us-east-1a", "us-east-1b", "us-east-1c"]

# Cluster sizing - medium for test
master_count = 3
worker_count = 3

# Instance types - balanced for test
instance_type_bastion = "t3.medium"
instance_type_master  = "t3.large"
instance_type_worker  = "t3.large"

# Security
allowed_ssh_cidr = "0.0.0.0/0"  # Restrict to your IP in production

# Monitoring
enable_monitoring = true

bucket_name = "petclinic-atos"

