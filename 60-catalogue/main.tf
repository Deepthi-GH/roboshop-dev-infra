# create EC2 instance
resource "aws_instance" "catalogue" {
  ami           = local.ami_id
  instance_type = "t3.micro"
  vpc_security_group_ids = [local.catalogue_sg_id]
  subnet_id     = local.private_subnet_id

  tags = merge (
    local.common_tags,
    {
        Name = "${local.common_name_suffix}-catalogue" #roboshop-dev-catalogue
    }
  )

}


# connect to instance using remote-exec provisioner through terraform data

resource "terraform_data" "catalogue" {
    triggers_replace = [
        aws_instance.catalogue.id # triggers when catalogue id changes
    ]

connection {
    type     = "ssh"
    user     = "ec2-user"
    password = "DevOps321"
    host     = aws_instance.catalogue.private_ip
}

# terraform copies the file to catalogue server

provisioner "file" {
    source      = "catalogue.sh"
    destination = "/tmp/catalogue.sh"
}

provisioner "remote-exec" {
    inline = [
        " chmod +x /tmp/catalogue.sh ",
        "sudo sh /tmp/catalogue.sh catalogue ${var.environment}" 
    
    ]
}
}

resource "aws_route53_record" "catalogue" {
  zone_id = var.zone_id
  name    = "catalogue-${var.environment}.${var.domain_name}" # catalogue-dev.deepthi.cloud
  type    = "A"
  ttl     = 1
  records = [aws_instance.catalogue.private_ip]
  allow_overwrite = true
}

# stop the instance to take AMI
resource "aws_ec2_instance_state" "catalogue" {
    instance_id = aws_instance.catalogue.id
    state       = "stopped"
    depends_on  = [terraform_data.catalogue]
}

# Take AMI
resource "aws_ami_from_instance" "catalogue" {
  name               = "${local.common_name_suffix}-catalogue-ami"
  source_instance_id = aws_instance.catalogue.id
  depends_on         = [aws_ec2_instance_state.catalogue]
  tags = merge (
    local.common_tags,
    {
        Name = "${local.common_name_suffix}-catalogue-ami" #roboshop-dev-catalogue-ami
    }
  )
}

# Create target group
resource "aws_lb_target_group" "catalogue" {
  name     = "${local.common_name_suffix}-catalogue"
  port     = 8080
  protocol = "HTTP"
  vpc_id   = local.vpc_id
  deregistration_delay = 60 # waiting period before deleting the instance.
  health_check {
    healthy_threshold  = 2
    interval           = 10
    matcher            = "200-299" 
    path               = "/health"
    port               = 8080
    protocol           = HTTP
    timeout            = 2
    unhealthy_threshold = 2
  }
}

resource "aws_launch_template" "catalogue" {
  name = "${local.common_name_suffix}-catalogue"
  instance_initiated_shutdown_behavior = "terminate" # terminate the instance after traffic is diverted
  image_id = aws_ami_from_instance.catalogue.id
  instance_type = "t3.micro"

  vpc_security_group_ids = [local.catalogue_sg_id]
  
  # tags attached to the instance
  tag_specifications {
    resource_type = "instance"

    tags = merge(
      local.common_tags,
     {
      Name = "${local.common_name_suffix}-catalogue"
    }
    )
  }
   
   # tags attached to the volume created by instance
    tag_specifications {
    resource_type = "volume"

    tags = merge(
      local.common_tags,
     {
      Name = "${local.common_name_suffix}-catalogue"
    }
    )
  }

 # tags attached to the launch template 
   tags = merge(
      local.common_tags,
     {
      Name = "${local.common_name_suffix}-catalogue"
    }
    )

}
 # AutoScaling group
resource "aws_autoscaling_group" "catalogue" {
  name                      = "${local.common_name_suffix}-catalogue"
  max_size                  = 10
  min_size                  = 1
  health_check_grace_period = 100
  health_check_type         = "ELB"
  desired_capacity          = 1
  force_delete              = false
  launch_template {
    id      = aws_launch_template.catalogue.id
    version = aws_launch_template.catalogue.latest_version
  }
  vpc_zone_identifier       = local.private_subnet_ids
  target_group_arns         = [aws_lb_target_group.catalogue.arn]

  dynamic "tag" { # we will get the iterator with the name as tag
    for_each = merge(
      local.common_tags,
      {
        Name = "${local.common_name_suffix}-catalogue"
      }
    )
    content {
    key                 = tag.key
    value               = tag.value
    propagate_at_launch = true
  }
  }
  timeouts {
    delete = "15m" # launch in 15m,otherwise timeout.
  }
}

# autoscaling policy
resource "aws_autoscaling_policy" "catalogue" {
  # ... other configuration ...
  autoscaling_group_name = aws_autoscaling_group.catalogue.name
  name                   = "${local.common_name_suffix}-catalogue"
  policy_type            = "TargetTrackingScaling"

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }

    target_value = 75.0
  }
}

# create LB Listener rule.
resource "aws_lb_listener_rule" "catalogue" {
  listener_arn = local.backend_alb_listener_arn
  priority     = 10

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.catalogue.arn
  }

  condition {
    host_header {
      values = ["catalogue.backend-alb-${var.environment}.${var.domain_name}"]
    }
  }
}