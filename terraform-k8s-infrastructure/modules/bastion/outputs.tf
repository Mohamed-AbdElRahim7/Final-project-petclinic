output "instance_id" {
  description = "Bastion instance ID"
  value       = aws_instance.bastion.id
}

output "private_ip" {
  description = "Bastion private IP"
  value       = aws_instance.bastion.private_ip
}

output "public_ip" {
  description = "Bastion public IP (EIP)"
  value       = aws_eip.bastion.public_ip
}

output "instance_arn" {
  description = "Bastion instance ARN"
  value       = aws_instance.bastion.arn
}