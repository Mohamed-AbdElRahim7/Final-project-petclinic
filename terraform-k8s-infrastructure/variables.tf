variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment name (dev, test, prod)"
  type        = string
  validation {
    condition     = contains(["dev", "test", "prod"], var.environment)
    error_message = "Environment must be dev, test, or prod."
  }
}

variable "owner" {
  description = "Project owner/team name"
  type        = string
  default     = "DevOps-Team"
}

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
  default     = "petclinic"
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "List of availability zones"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b", "us-east-1c"]
}

variable "master_count" {
  description = "Number of master nodes"
  type        = number
  default     = 3
}

variable "worker_count" {
  description = "Number of worker nodes (can be scaled from 3 to 6)"
  type        = number
  default     = 3
  validation {
    condition     = var.worker_count >= 3 && var.worker_count <= 6
    error_message = "Worker count must be between 3 and 6."
  }
}

variable "instance_type_bastion" {
  description = "EC2 instance type for bastion"
  type        = string
  default     = "t3.medium"
}

variable "instance_type_master" {
  description = "EC2 instance type for master nodes"
  type        = string
  default     = "t3.large"
}

variable "instance_type_worker" {
  description = "EC2 instance type for worker nodes"
  type        = string
  default     = "t3.large"
}

variable "ssh_key_name" {
  description = "Name of the SSH key pair"
  type        = string
}

variable "allowed_ssh_cidr" {
  description = "CIDR block allowed to SSH to bastion"
  type        = string
  default     = "0.0.0.0/0"
}

variable "enable_monitoring" {
  description = "Enable CloudWatch detailed monitoring"
  type        = bool
  default     = true
}


variable "bucket_name" {
  type        = string
  default     = "petclinic-atos"
}

