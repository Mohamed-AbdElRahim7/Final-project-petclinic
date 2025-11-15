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

# Worker Node EC2 Instances
resource "aws_instance" "worker" {
  count = var.worker_count

  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  subnet_id              = element(var.subnet_ids, count.index % length(var.subnet_ids))
  vpc_security_group_ids = var.security_group_ids
  key_name               = var.key_name
  # iam_instance_profile removed - no IAM permissions

  user_data = templatefile("${path.module}/user-data.sh", {
    hostname   = "${var.project_name}-${var.environment}-worker-${count.index + 1}"
    node_index = count.index + 1
    node_type  = "worker"
  })

  root_block_device {
    volume_type           = "gp3"
    volume_size           = 100
    iops                  = 3000
    throughput            = 125
    delete_on_termination = true
    encrypted             = true
  }

  # Additional volume for container images and volumes
  ebs_block_device {
    device_name           = "/dev/sdf"
    volume_type           = "gp3"
    volume_size           = 100
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
    Name                                        = "${var.project_name}-${var.environment}-worker-${count.index + 1}"
    Role                                        = "Worker"
#    "kubernetes.io/cluster/${var.project_name}" = "owned"
    NodeIndex                                   = count.index + 1
  }

  lifecycle {
    create_before_destroy = true
  }
}
