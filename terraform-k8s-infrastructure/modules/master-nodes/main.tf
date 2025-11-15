# Get latest Ubuntu 22.04 LTS AMI
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# Master Node EC2 Instances
resource "aws_instance" "master" {
  count = var.master_count

  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  subnet_id              = element(var.subnet_ids, count.index)
  vpc_security_group_ids = var.security_group_ids
  key_name               = var.key_name
  # iam_instance_profile removed - no IAM permissions

  user_data = templatefile("${path.module}/user-data.sh", {
    hostname    = "${var.project_name}-${var.environment}-master-${count.index + 1}"
    node_index  = count.index + 1
    node_type   = "master"
  })

  root_block_device {
    volume_type           = "gp3"
    volume_size           = 50
    iops                  = 3000
    throughput            = 125
    delete_on_termination = true
    encrypted             = true
  }

  # Additional volume for etcd data
  ebs_block_device {
    device_name           = "/dev/sdf"
    volume_type           = "gp3"
    volume_size           = 20
    iops                  = 3000
    throughput            = 125
    delete_on_termination = true
    encrypted             = true
  }

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
    instance_metadata_tags      = "enabled"
  }

  monitoring = false  # Detailed monitoring disabled

  tags = {
    Name                                        = "${var.project_name}-${var.environment}-master-${count.index + 1}"
    Role                                        = "Master"
#    "kubernetes.io/cluster/${var.project_name}" = "owned"
    NodeIndex                                   = count.index + 1
  }
}

# Attach master instances to target group
resource "aws_lb_target_group_attachment" "master" {
  count = var.master_count

  target_group_arn = var.target_group_arn
  target_id        = aws_instance.master[count.index].id
  port             = 6443
}
