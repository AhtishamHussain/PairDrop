resource "aws_ssm_parameter" "image_tag" {
  name  = "/pairdrop/image_tag"
  type  = "String"
  value = "placeholder"
  lifecycle {
    ignore_changes = [value]
  }
}

resource "aws_eip" "app" {
  domain = "vpc"
  tags   = { Name = "${local.name}-eip" }
}

resource "aws_launch_template" "app" {
  name_prefix            = "${local.name}-"
  image_id               = data.aws_ami.al2023.id
  instance_type          = var.instance_type
  update_default_version = true
  iam_instance_profile {
    name = aws_iam_instance_profile.ec2.name
  }
  vpc_security_group_ids = [aws_security_group.app.id]
  user_data = base64encode(templatefile("${path.module}/user_data.sh.tftpl", {
    eip_allocation_id = aws_eip.app.id
    region            = var.aws_region
    domain            = var.domain
    acme_email        = var.acme_email
    github_org        = var.github_org
    github_repo       = var.github_repo
  }))
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 2
  }
  monitoring {
    enabled = false
  }
  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_size           = 20
      volume_type           = "gp3"
      encrypted             = true
      delete_on_termination = true
    }
  }
}

resource "aws_autoscaling_group" "app" {
  name                      = local.name
  min_size                  = 1
  max_size                  = var.max_size
  desired_capacity          = var.desired_capacity
  vpc_zone_identifier       = aws_subnet.public[*].id
  health_check_type         = "EC2"
  health_check_grace_period = 300
  launch_template {
    id      = aws_launch_template.app.id
    version = "$Latest"
  }
  instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage = 0
      instance_warmup        = 120
    }
  }
  tag {
    key                 = "Name"
    value               = local.name
    propagate_at_launch = true
  }
}

resource "aws_autoscaling_policy" "cpu" {
  count                  = var.max_size > 1 ? 1 : 0
  name                   = "${local.name}-cpu"
  autoscaling_group_name = aws_autoscaling_group.app.name
  policy_type            = "TargetTrackingScaling"
  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }
    target_value = 70
  }
}
