# The Packer AMI from the previous lecture, found by name. Never an id.
data "aws_ami" "node" {
  owners      = ["self"]
  most_recent = true

  filter {
    name   = "name"
    values = ["k8s-node-1.36.4"]
  }
}

# Bastion only: Canonical's Ubuntu 24.04 image.
data "aws_ami" "ubuntu" {
  owners      = ["099720109477"]
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }
}

resource "aws_key_pair" "admin" {
  key_name   = "${var.cluster_id}-admin"
  public_key = file(pathexpand(var.ssh_public_key_path))
}

# ---------------------------------------------------------------- launch templates
resource "aws_launch_template" "control_plane" {
  name_prefix            = "${var.cluster_id}-cp-"
  image_id               = data.aws_ami.node.id
  instance_type          = var.control_plane_type
  key_name               = aws_key_pair.admin.key_name
  vpc_security_group_ids = [aws_security_group.nodes.id, aws_security_group.control_plane.id]
  user_data              = base64encode(file("${path.module}/set-hostname.sh"))

  iam_instance_profile {
    name = aws_iam_instance_profile.control_plane.name
  }

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required" # IMDSv2 only
  }

  block_device_mappings {
    device_name = "/dev/sda1"

    ebs {
      volume_type = "gp3"
      volume_size = 30
    }
  }

  tag_specifications {
    resource_type = "instance"

    tags = {
      Name                                      = "${var.cluster_id}-control-plane"
      "kubernetes.io/cluster/${var.cluster_id}" = "owned"
    }
  }
}

resource "aws_launch_template" "worker" {
  name_prefix            = "${var.cluster_id}-worker-"
  image_id               = data.aws_ami.node.id
  instance_type          = var.worker_type
  key_name               = aws_key_pair.admin.key_name
  vpc_security_group_ids = [aws_security_group.nodes.id]
  user_data              = base64encode(file("${path.module}/set-hostname.sh"))

  iam_instance_profile {
    name = aws_iam_instance_profile.node.name
  }

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required" # IMDSv2 only
  }

  block_device_mappings {
    device_name = "/dev/sda1"

    ebs {
      volume_type = "gp3"
      volume_size = 30
    }
  }
}

# ---------------------------------------------------------------- control plane: one fixed identity
resource "aws_instance" "control_plane" {
  subnet_id = aws_subnet.private.id

  launch_template {
    id      = aws_launch_template.control_plane.id
    version = "$Latest"
  }

  tags = {
    Name                                      = "${var.cluster_id}-control-plane"
    "kubernetes.io/cluster/${var.cluster_id}" = "owned"
  }

  # The user data comes from the launch template. Without this, any later apply would try to
  # clear it, and stop and restart the control plane to do so.
  lifecycle {
    ignore_changes = [user_data]
  }
}

# ---------------------------------------------------------------- workers: an Auto Scaling group
resource "aws_autoscaling_group" "workers" {
  name                = "${var.cluster_id}-workers"
  min_size            = var.worker_count
  max_size            = var.worker_count
  desired_capacity    = var.worker_count
  vpc_zone_identifier = [aws_subnet.private.id]

  launch_template {
    id      = aws_launch_template.worker.id
    version = "$Latest"
  }

  tag {
    key                 = "kubernetes.io/cluster/${var.cluster_id}"
    value               = "owned"
    propagate_at_launch = true
  }

  tag {
    key                 = "Name"
    value               = "${var.cluster_id}-worker"
    propagate_at_launch = true
  }
}

# ---------------------------------------------------------------- bastion: the one way in
resource "aws_instance" "bastion" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = "t3.micro"
  subnet_id                   = aws_subnet.public.id
  vpc_security_group_ids      = [aws_security_group.bastion.id]
  key_name                    = aws_key_pair.admin.key_name
  associate_public_ip_address = true

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  tags = {
    Name = "${var.cluster_id}-bastion"
  }
}

# ---------------------------------------------------------------- API load balancer on 6443
resource "aws_lb" "api" {
  name               = "${var.cluster_id}-api"
  load_balancer_type = "network"
  internal           = false
  subnets            = [aws_subnet.public.id]
  security_groups    = [aws_security_group.api_lb.id]
}

resource "aws_lb_target_group" "api" {
  name        = "${var.cluster_id}-api"
  port        = 6443
  protocol    = "TCP"
  vpc_id      = aws_vpc.main.id
  target_type = "instance"

  # Off: the control plane calling its own API through the load balancer would otherwise hairpin.
  preserve_client_ip = false

  health_check {
    protocol            = "TCP"
    port                = "traffic-port"
    interval            = 10
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

resource "aws_lb_listener" "api" {
  load_balancer_arn = aws_lb.api.arn
  port              = 6443
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.api.arn
  }
}

resource "aws_lb_target_group_attachment" "control_plane" {
  target_group_arn = aws_lb_target_group.api.arn
  target_id        = aws_instance.control_plane.id
  port             = 6443
}
