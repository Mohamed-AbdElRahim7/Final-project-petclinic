output "instance_ids" {
  description = "List of worker instance IDs"
  value       = aws_instance.worker[*].id
}

output "private_ips" {
  description = "List of worker private IPs"
  value       = aws_instance.worker[*].private_ip
}

output "instance_arns" {
  description = "List of worker instance ARNs"
  value       = aws_instance.worker[*].arn
}