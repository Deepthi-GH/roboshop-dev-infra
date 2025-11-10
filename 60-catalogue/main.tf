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
    protocol           = "HTTP"
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

resource "terraform_data" "catalogue_local" {
    triggers_replace = [
        aws_instance.catalogue.id # triggers when catalogue id changes
    ]
depends_on = [ aws_autoscaling_policy.catalogue ]
provisioner "local-exec" {
    command = "aws ec2 terminate-instances --instance-ids ${aws_instance.catalogue.id}"
}
}


resource "aws_instance" "user" {
  ami           = local.ami_id
  instance_type = var.instance_type
  vpc_security_group_ids = [local.user_sg_id]
  subnet_id     = local.private_subnet_id

 tags = merge (
    local.common_tags,
    {
        Name = "${local.common_name_suffix}-user" #roboshop-dev-user
    }
  )
}

# connect to instance using remote-exec provisioner through terraform data

resource "terraform_data" "user" {
    depends_on = [terraform_data.catalogue]
    triggers_replace = [
        aws_instance.user.id # triggers when user id changes
    ]

connection {
    type     = "ssh"
    user     = "ec2-user"
    password = "DevOps321"
    host     = aws_instance.user.private_ip
}

# terraform copies the file to user server

provisioner "file" {
    source      = "user.sh"
    destination = "/tmp/user.sh"
}

provisioner "remote-exec" {
    inline = [
        " chmod +x /tmp/user.sh ",
        "sudo sh /tmp/user.sh user ${var.environment}" 
    
    ]
}
}

resource "aws_route53_record" "user" {
  zone_id = var.zone_id
  name    = "user-${var.environment}.${var.domain_name}" # user-dev.deepthi.cloud
  type    = "A"
  ttl     = 1
  records = [aws_instance.user.private_ip]
  allow_overwrite = true
}

# stop the instance
resource "aws_ec2_instance_state" "user" {
  instance_id = aws_instance.user.id
  state       = "stopped"
  depends_on  = [terraform_data.user]
}

# Take AMI
resource "aws_ami_from_instance" "user" {
  name               = "${local.common_name_suffix}-user"
  source_instance_id = aws_instance.user.id
  depends_on         = [aws_ec2_instance_state.user]

   tags = merge (
    local.common_tags,
    {
        Name = "${local.common_name_suffix}-user" #roboshop-dev-user
    }
  )
}

# create target group
resource "aws_lb_target_group" "user" {
  name     = "${local.common_name_suffix}-user"
  port     = 8080
  protocol = "HTTP"
  vpc_id   = local.vpc_id # Replace with your VPC ID
  deregistration_delay = 60 # waiting period before deleting the instance.
  health_check {
    path                = "/health"
    protocol            = "HTTP"
    port                = 8080
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 2
    interval            = 10
    matcher             = "200-299"
  }

    tags = merge (
    local.common_tags,
    {
        Name = "${local.common_name_suffix}-user" #roboshop-dev-user
    }
  )
}

# Launch Template
resource "aws_launch_template" "user" {
  name = "${local.common_name_suffix}-user" 
  image_id = aws_ami_from_instance.user.id
  instance_initiated_shutdown_behavior = "terminate"
  instance_type = "t3.micro"
  vpc_security_group_ids = [local.user_sg_id]

  tag_specifications {
    resource_type = "instance"

      tags = merge (
    local.common_tags,
    {
        Name = "${local.common_name_suffix}-user" #roboshop-dev-user
    }
  )
  }

   # tags attached to the volume created by instance
    tag_specifications {
    resource_type = "volume"

    tags = merge(
      local.common_tags,
     {
      Name = "${local.common_name_suffix}-user"
    }
    )
  }

 # tags attached to the launch template 
   tags = merge(
      local.common_tags,
     {
      Name = "${local.common_name_suffix}-user"
    }
    )

}

# give launch template to auto scaling.

# AutoScaling group
resource "aws_autoscaling_group" "user" {
  name                      = "${local.common_name_suffix}-user"
  max_size                  = 10
  min_size                  = 1
  health_check_grace_period = 100
  health_check_type         = "ELB"
  desired_capacity          = 1
  force_delete              = false
  launch_template {
    id      = aws_launch_template.user.id
    version = aws_launch_template.user.latest_version
  }
  vpc_zone_identifier       = local.private_subnet_ids
  target_group_arns         = [aws_lb_target_group.user.arn]

  dynamic "tag" { # we will get the iterator with the name as tag
    for_each = merge(
      local.common_tags,
      {
        Name = "${local.common_name_suffix}-user"
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
resource "aws_autoscaling_policy" "user" {
  # ... other configuration ...
  autoscaling_group_name = aws_autoscaling_group.user.name
  name                   = "${local.common_name_suffix}-user"
  policy_type            = "TargetTrackingScaling"

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }

    target_value = 75.0
  }
}

# create LB Listener rule.
resource "aws_lb_listener_rule" "user" {
  listener_arn = local.backend_alb_listener_arn
  priority     = 11

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.user.arn
  }

  condition {
    host_header {
      values = ["user.backend-alb-${var.environment}.${var.domain_name}"]
    }
  }
}

resource "terraform_data" "user_local" {
    triggers_replace = [
        aws_instance.user.id # triggers when user id changes
    ]
depends_on = [ aws_autoscaling_policy.user ]
provisioner "local-exec" {
    command = "aws ec2 terminate-instances --instance-ids ${aws_instance.user.id}"
}
}

# create EC2 instance
resource "aws_instance" "cart" {
  ami           = local.ami_id
  instance_type = "t3.micro"
  vpc_security_group_ids = [local.cart_sg_id]
  subnet_id     = local.private_subnet_id

  tags = merge (
    local.common_tags,
    {
        Name = "${local.common_name_suffix}-cart" #roboshop-dev-cart
    }
  )

}


# connect to instance using remote-exec provisioner through terraform data

resource "terraform_data" "cart" {
depends_on = [terraform_data.user]
    triggers_replace = [
        aws_instance.cart.id # triggers when cart id changes
    ]

connection {
    type     = "ssh"
    user     = "ec2-user"
    password = "DevOps321"
    host     = aws_instance.cart.private_ip
}

# terraform copies the file to cart server

provisioner "file" {
    source      = "cart.sh"
    destination = "/tmp/cart.sh"
}

provisioner "remote-exec" {
    inline = [
        " chmod +x /tmp/cart.sh ",
        "sudo sh /tmp/cart.sh cart ${var.environment}" 
    
    ]
}
}

resource "aws_route53_record" "cart" {
  zone_id = var.zone_id
  name    = "cart-${var.environment}.${var.domain_name}" # cart-dev.deepthi.cloud
  type    = "A"
  ttl     = 1
  records = [aws_instance.cart.private_ip]
  allow_overwrite = true
}

# stop the instance to take AMI
resource "aws_ec2_instance_state" "cart" {
    instance_id = aws_instance.cart.id
    state       = "stopped"
    depends_on  = [terraform_data.cart]
}

# Take AMI
resource "aws_ami_from_instance" "cart" {
  name               = "${local.common_name_suffix}-cart-ami"
  source_instance_id = aws_instance.cart.id
  depends_on         = [aws_ec2_instance_state.cart]
  tags = merge (
    local.common_tags,
    {
        Name = "${local.common_name_suffix}-cart-ami" #roboshop-dev-cart-ami
    }
  )
}

# Create target group
resource "aws_lb_target_group" "cart" {
  name     = "${local.common_name_suffix}-cart"
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
    protocol           = "HTTP"
    timeout            = 2
    unhealthy_threshold = 2
  }
}

resource "aws_launch_template" "cart" {
  name = "${local.common_name_suffix}-cart"
  instance_initiated_shutdown_behavior = "terminate" # terminate the instance after traffic is diverted
  image_id = aws_ami_from_instance.cart.id
  instance_type = "t3.micro"

  vpc_security_group_ids = [local.cart_sg_id]
  
  # tags attached to the instance
  tag_specifications {
    resource_type = "instance"

    tags = merge(
      local.common_tags,
     {
      Name = "${local.common_name_suffix}-cart"
    }
    )
  }
   
   # tags attached to the volume created by instance
    tag_specifications {
    resource_type = "volume"

    tags = merge(
      local.common_tags,
     {
      Name = "${local.common_name_suffix}-cart"
    }
    )
  }

 # tags attached to the launch template 
   tags = merge(
      local.common_tags,
     {
      Name = "${local.common_name_suffix}-cart"
    }
    )

}
 # AutoScaling group
resource "aws_autoscaling_group" "cart" {
  name                      = "${local.common_name_suffix}-cart"
  max_size                  = 10
  min_size                  = 1
  health_check_grace_period = 100
  health_check_type         = "ELB"
  desired_capacity          = 1
  force_delete              = false
  launch_template {
    id      = aws_launch_template.cart.id
    version = aws_launch_template.cart.latest_version
  }
  vpc_zone_identifier       = local.private_subnet_ids
  target_group_arns         = [aws_lb_target_group.cart.arn]

  dynamic "tag" { # we will get the iterator with the name as tag
    for_each = merge(
      local.common_tags,
      {
        Name = "${local.common_name_suffix}-cart"
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
resource "aws_autoscaling_policy" "cart" {
  # ... other configuration ...
  autoscaling_group_name = aws_autoscaling_group.cart.name
  name                   = "${local.common_name_suffix}-cart"
  policy_type            = "TargetTrackingScaling"

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }

    target_value = 75.0
  }
}

# create LB Listener rule.
resource "aws_lb_listener_rule" "cart" {
  listener_arn = local.backend_alb_listener_arn
  priority     = 12

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.cart.arn
  }

  condition {
    host_header {
      values = ["cart.backend-alb-${var.environment}.${var.domain_name}"]
    }
  }
}

resource "terraform_data" "cart_local" {
    triggers_replace = [
        aws_instance.cart.id # triggers when cart id changes
    ]
depends_on = [ aws_autoscaling_policy.cart ]
provisioner "local-exec" {
    command = "aws ec2 terminate-instances --instance-ids ${aws_instance.cart.id}"
}
}

# create EC2 instance
resource "aws_instance" "shipping" {
  ami           = local.ami_id
  instance_type = "t3.micro"
  vpc_security_group_ids = [local.shipping_sg_id]
  subnet_id     = local.private_subnet_id

  tags = merge (
    local.common_tags,
    {
        Name = "${local.common_name_suffix}-shipping" #roboshop-dev-shipping
    }
  )

}


# connect to instance using remote-exec provisioner through terraform data

resource "terraform_data" "shipping" {
depends_on = [terraform_data.cart]
    triggers_replace = [
        aws_instance.shipping.id # triggers when shipping id changes
    ]

connection {
    type     = "ssh"
    user     = "ec2-user"
    password = "DevOps321"
    host     = aws_instance.shipping.private_ip
}

# terraform copies the file to shipping server

provisioner "file" {
    source      = "shipping.sh"
    destination = "/tmp/shipping.sh"
}

provisioner "remote-exec" {
    inline = [
        " chmod +x /tmp/shipping.sh ",
        "sudo sh /tmp/shipping.sh shipping ${var.environment}" 
    
    ]
}
}

resource "aws_route53_record" "shipping" {
  zone_id = var.zone_id
  name    = "shipping-${var.environment}.${var.domain_name}" # shipping-dev.deepthi.cloud
  type    = "A"
  ttl     = 1
  records = [aws_instance.shipping.private_ip]
  allow_overwrite = true
}

# stop the instance to take AMI
resource "aws_ec2_instance_state" "shipping" {
    instance_id = aws_instance.shipping.id
    state       = "stopped"
    depends_on  = [terraform_data.shipping]
}

# Take AMI
resource "aws_ami_from_instance" "shipping" {
  name               = "${local.common_name_suffix}-shipping-ami"
  source_instance_id = aws_instance.shipping.id
  depends_on         = [aws_ec2_instance_state.shipping]
  tags = merge (
    local.common_tags,
    {
        Name = "${local.common_name_suffix}-shipping-ami" #roboshop-dev-shipping-ami
    }
  )
}

# Create target group
resource "aws_lb_target_group" "shipping" {
  name     = "${local.common_name_suffix}-shipping"
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
    protocol           = "HTTP"
    timeout            = 2
    unhealthy_threshold = 2
  }
}

resource "aws_launch_template" "shipping" {
  name = "${local.common_name_suffix}-shipping"
  instance_initiated_shutdown_behavior = "terminate" # terminate the instance after traffic is diverted
  image_id = aws_ami_from_instance.shipping.id
  instance_type = "t3.micro"

  vpc_security_group_ids = [local.shipping_sg_id]
  
  # tags attached to the instance
  tag_specifications {
    resource_type = "instance"

    tags = merge(
      local.common_tags,
     {
      Name = "${local.common_name_suffix}-shipping"
    }
    )
  }
   
   # tags attached to the volume created by instance
    tag_specifications {
    resource_type = "volume"

    tags = merge(
      local.common_tags,
     {
      Name = "${local.common_name_suffix}-shipping"
    }
    )
  }

 # tags attached to the launch template 
   tags = merge(
      local.common_tags,
     {
      Name = "${local.common_name_suffix}-shipping"
    }
    )

}
 # AutoScaling group
resource "aws_autoscaling_group" "shipping" {
  name                      = "${local.common_name_suffix}-shipping"
  max_size                  = 10
  min_size                  = 1
  health_check_grace_period = 100
  health_check_type         = "ELB"
  desired_capacity          = 1
  force_delete              = false
  launch_template {
    id      = aws_launch_template.shipping.id
    version = aws_launch_template.shipping.latest_version
  }
  vpc_zone_identifier       = local.private_subnet_ids
  target_group_arns         = [aws_lb_target_group.shipping.arn]

  dynamic "tag" { # we will get the iterator with the name as tag
    for_each = merge(
      local.common_tags,
      {
        Name = "${local.common_name_suffix}-shipping"
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
resource "aws_autoscaling_policy" "shipping" {
  # ... other configuration ...
  autoscaling_group_name = aws_autoscaling_group.shipping.name
  name                   = "${local.common_name_suffix}-shipping"
  policy_type            = "TargetTrackingScaling"

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }

    target_value = 75.0
  }
}

# create LB Listener rule.
resource "aws_lb_listener_rule" "shipping" {
  listener_arn = local.backend_alb_listener_arn
  priority     = 13

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.shipping.arn
  }

  condition {
    host_header {
      values = ["shipping.backend-alb-${var.environment}.${var.domain_name}"]
    }
  }
}

resource "terraform_data" "shipping_local" {
    triggers_replace = [
        aws_instance.shipping.id # triggers when shipping id changes
    ]
depends_on = [ aws_autoscaling_policy.shipping ]
provisioner "local-exec" {
    command = "aws ec2 terminate-instances --instance-ids ${aws_instance.shipping.id}"
}
}

# create EC2 instance
resource "aws_instance" "payment" {
  ami           = local.ami_id
  instance_type = "t3.micro"
  vpc_security_group_ids = [local.payment_sg_id]
  subnet_id     = local.private_subnet_id

  tags = merge (
    local.common_tags,
    {
        Name = "${local.common_name_suffix}-payment" #roboshop-dev-payment
    }
  )

}


# connect to instance using remote-exec provisioner through terraform data

resource "terraform_data" "payment" {
depends_on = [terraform_data.shipping]
    triggers_replace = [
        aws_instance.payment.id # triggers when payment id changes
    ]

connection {
    type     = "ssh"
    user     = "ec2-user"
    password = "DevOps321"
    host     = aws_instance.payment.private_ip
}

# terraform copies the file to payment server

provisioner "file" {
    source      = "payment.sh"
    destination = "/tmp/payment.sh"
}

provisioner "remote-exec" {
    inline = [
        " chmod +x /tmp/payment.sh ",
        "sudo sh /tmp/payment.sh payment ${var.environment}" 
    
    ]
}
}

resource "aws_route53_record" "payment" {
  zone_id = var.zone_id
  name    = "payment-${var.environment}.${var.domain_name}" # payment-dev.deepthi.cloud
  type    = "A"
  ttl     = 1
  records = [aws_instance.payment.private_ip]
  allow_overwrite = true
}

# stop the instance to take AMI
resource "aws_ec2_instance_state" "payment" {
    instance_id = aws_instance.payment.id
    state       = "stopped"
    depends_on  = [terraform_data.payment]
}

# Take AMI
resource "aws_ami_from_instance" "payment" {
  name               = "${local.common_name_suffix}-payment-ami"
  source_instance_id = aws_instance.payment.id
  depends_on         = [aws_ec2_instance_state.payment]
  tags = merge (
    local.common_tags,
    {
        Name = "${local.common_name_suffix}-payment-ami" #roboshop-dev-payment-ami
    }
  )
}

# Create target group
resource "aws_lb_target_group" "payment" {
  name     = "${local.common_name_suffix}-payment"
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
    protocol           = "HTTP"
    timeout            = 2
    unhealthy_threshold = 2
  }
}

resource "aws_launch_template" "payment" {
  name = "${local.common_name_suffix}-payment"
  instance_initiated_shutdown_behavior = "terminate" # terminate the instance after traffic is diverted
  image_id = aws_ami_from_instance.payment.id
  instance_type = "t3.micro"

  vpc_security_group_ids = [local.payment_sg_id]
  
  # tags attached to the instance
  tag_specifications {
    resource_type = "instance"

    tags = merge(
      local.common_tags,
     {
      Name = "${local.common_name_suffix}-payment"
    }
    )
  }
   
   # tags attached to the volume created by instance
    tag_specifications {
    resource_type = "volume"

    tags = merge(
      local.common_tags,
     {
      Name = "${local.common_name_suffix}-payment"
    }
    )
  }

 # tags attached to the launch template 
   tags = merge(
      local.common_tags,
     {
      Name = "${local.common_name_suffix}-payment"
    }
    )

}
 # AutoScaling group
resource "aws_autoscaling_group" "payment" {
  name                      = "${local.common_name_suffix}-payment"
  max_size                  = 10
  min_size                  = 1
  health_check_grace_period = 100
  health_check_type         = "ELB"
  desired_capacity          = 1
  force_delete              = false
  launch_template {
    id      = aws_launch_template.payment.id
    version = aws_launch_template.payment.latest_version
  }
  vpc_zone_identifier       = local.private_subnet_ids
  target_group_arns         = [aws_lb_target_group.payment.arn]

  dynamic "tag" { # we will get the iterator with the name as tag
    for_each = merge(
      local.common_tags,
      {
        Name = "${local.common_name_suffix}-payment"
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
resource "aws_autoscaling_policy" "payment" {
  # ... other configuration ...
  autoscaling_group_name = aws_autoscaling_group.payment.name
  name                   = "${local.common_name_suffix}-payment"
  policy_type            = "TargetTrackingScaling"

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }

    target_value = 75.0
  }
}

# create LB Listener rule.
resource "aws_lb_listener_rule" "payment" {
  listener_arn = local.backend_alb_listener_arn
  priority     = 14

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.payment.arn
  }

  condition {
    host_header {
      values = ["payment.backend-alb-${var.environment}.${var.domain_name}"]
    }
  }
}

resource "terraform_data" "payment_local" {
    triggers_replace = [
        aws_instance.payment.id # triggers when payment id changes
    ]
depends_on = [ aws_autoscaling_policy.payment ]
provisioner "local-exec" {
    command = "aws ec2 terminate-instances --instance-ids ${aws_instance.payment.id}"
}
}
