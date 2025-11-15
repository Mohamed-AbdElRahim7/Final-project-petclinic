output "bastion_public_ip" {
  description = "Public IP of bastion host"
  value       = module.bastion.public_ip
}

output "bastion_connection_command" {
  description = "SSH command to connect to bastion"
  value       = "ssh -i ${var.project_name}-${var.environment}-key.pem ubuntu@${module.bastion.public_ip}"
}

output "master_private_ips" {
  description = "Private IPs of master nodes"
  value       = module.master_nodes.private_ips
}

output "worker_private_ips" {
  description = "Private IPs of worker nodes"
  value       = module.worker_nodes.private_ips
}

output "master_load_balancer_dns" {
  description = "DNS name of master load balancer"
  value       = module.load_balancer.lb_dns_name
}

output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}

output "private_key_location" {
  description = "Location of SSH private key file"
  value       = "${path.module}/${var.project_name}-${var.environment}-key.pem"
}

output "ssh_private_key" {
  description = "SSH private key (sensitive)"
  value       = tls_private_key.k8s_key.private_key_pem
  sensitive   = true
}

output "master_instance_ids" {
  description = "Instance IDs of master nodes"
  value       = module.master_nodes.instance_ids
}

output "worker_instance_ids" {
  description = "Instance IDs of worker nodes"
  value       = module.worker_nodes.instance_ids
}
