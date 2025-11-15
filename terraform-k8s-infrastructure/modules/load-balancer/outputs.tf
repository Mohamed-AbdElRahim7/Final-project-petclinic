output "lb_arn" {
  description = "Load balancer ARN"
  value       = aws_lb.master.arn
}

output "lb_dns_name" {
  description = "Load balancer DNS name"
  value       = aws_lb.master.dns_name
}

output "lb_zone_id" {
  description = "Load balancer zone ID"
  value       = aws_lb.master.zone_id
}

output "master_target_group_arn" {
  description = "Master target group ARN"
  value       = aws_lb_target_group.master.arn
}