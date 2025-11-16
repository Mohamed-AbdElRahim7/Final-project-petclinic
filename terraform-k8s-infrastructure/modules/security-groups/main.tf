##############################
# Bastion Security Group
##############################
resource "aws_security_group" "bastion" {
  name        = "${var.project_name}-${var.environment}-bastion-sg"
  description = "Security group for bastion host - only SSH from internet"
  vpc_id      = var.vpc_id

  # SSH from your IP / office
  ingress {
    description = "SSH from allowed CIDR"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.allowed_ssh_cidr]
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-bastion-sg"
  }
}

##############################
# Master Nodes Security Group
##############################
resource "aws_security_group" "master" {
  name        = "${var.project_name}-${var.environment}-master-sg"
  description = "Security group for K8s master nodes"
  vpc_id      = var.vpc_id

  # SSH from bastion only
  ingress {
    description     = "SSH from bastion"
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion.id]
  }

  # Kubernetes API server from bastion
  ingress {
    description     = "K8s API from bastion"
    from_port       = 6443
    to_port         = 6443
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion.id]
  }

  # ✅ أهم حاجة: K8s API من كل الـ VPC عشان kubelet / controllers / pods
  ingress {
    description = "K8s API from VPC"
    from_port   = 6443
    to_port     = 6443
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  # K8s API from load balancer (لو استخدمت NLB داخلي)
  ingress {
    description     = "K8s API from LB"
    from_port       = 6443
    to_port         = 6443
    protocol        = "tcp"
    security_groups = [aws_security_group.lb.id]
  }

  # All traffic between masters
  ingress {
    description = "All traffic between masters"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    self        = true
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-master-sg"
  }
}

##############################
# Worker Nodes Security Group
##############################
resource "aws_security_group" "worker" {
  name        = "${var.project_name}-${var.environment}-worker-sg"
  description = "Security group for K8s worker nodes"
  vpc_id      = var.vpc_id

  # SSH from bastion only
  ingress {
    description     = "SSH from bastion"
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion.id]
  }

  # NodePort Services inside VPC
  ingress {
    description = "NodePort Services"
    from_port   = 30000
    to_port     = 32767
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  # CNI and overlay network (Calico/Flannel) داخل الـ VPC
  ingress {
    description = "CNI traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [var.vpc_cidr]
  }

  # All traffic between workers
  ingress {
    description = "All traffic between workers"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    self        = true
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-worker-sg"
  }
}

##############################
# Load Balancer Security Group
##############################
resource "aws_security_group" "lb" {
  name        = "${var.project_name}-${var.environment}-lb-sg"
  description = "Security group for master load balancer"
  vpc_id      = var.vpc_id

  # K8s API from VPC
  ingress {
    description = "K8s API from VPC"
    from_port   = 6443
    to_port     = 6443
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  # Allow from bastion
  ingress {
    description     = "K8s API from bastion"
    from_port       = 6443
    to_port         = 6443
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion.id]
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-lb-sg"
  }
}

##############################
# Extra rules (separate resources)
##############################

# Allow master -> worker (Kubelet 10250)
resource "aws_security_group_rule" "worker_from_master" {
  type                     = "ingress"
  from_port                = 10250
  to_port                  = 10250
  protocol                 = "tcp"
  security_group_id        = aws_security_group.worker.id
  source_security_group_id = aws_security_group.master.id
}

# Allow worker -> master (all required traffic)
resource "aws_security_group_rule" "master_from_worker" {
  type                     = "ingress"
  from_port                = 0
  to_port                  = 0
  protocol                 = "-1"
  security_group_id        = aws_security_group.master.id
  source_security_group_id = aws_security_group.worker.id
}
