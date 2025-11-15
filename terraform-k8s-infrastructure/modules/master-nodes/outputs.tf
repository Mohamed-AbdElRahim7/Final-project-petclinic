output "instance_ids" {
  description = "List of master instance IDs"
  value       = aws_instance.master[*].id
}

output "private_ips" {
  description = "List of master private IPs"
  value       = aws_instance.master[*].private_ip
}

output "instance_arns" {
  description = "List of master instance ARNs"
  value       = aws_instance.master[*].arn
}