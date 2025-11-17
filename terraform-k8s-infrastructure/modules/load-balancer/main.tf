resource "aws_lb" "master" {
  name               = "${var.project_name}-${var.environment}-master-nlb"
  internal           = true
  load_balancer_type = "network"
  subnets            = var.subnet_ids
  security_groups    = var.security_group_ids

  enable_deletion_protection       = false
  enable_cross_zone_load_balancing = true

  tags = {
    Name = "${var.project_name}-${var.environment}-master-nlb"
    Role = "KubernetesAPI"
  }
}

resource "aws_lb_target_group" "master" {
  name     = "${var.project_name}-${var.environment}-master-tg"
  port     = 6443
  protocol = "TCP"
  vpc_id   = var.vpc_id

  health_check {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 2
    interval            = 10
    timeout             = 10
    protocol            = "TCP"
    port                = "6443"
  }

  deregistration_delay = 30

  stickiness {
    enabled = false
    type    = "source_ip"
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-master-tg"
  }
}

resource "aws_lb_listener" "master" {
  load_balancer_arn = aws_lb.master.arn
  port              = 6443
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.master.arn
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-master-listener"
  }
}
