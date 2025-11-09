# # frontend accepting traffic from frontend LB.
# resource "aws_security_group_rule" "frontned_frontend_lb" {
#   type                      = "ingress"
#   security_group_id         = module.sg[9].sg_id # forntend SG_ID
#   source_security_group_id  = module.sg[11].sg_id # frontend LB SG_ID
#   from_port                 = 80
#   protocol                  = "tcp"
#   to_port                   = 80
# }


# backend accepting traffic from bastion.
resource "aws_security_group_rule" "backend_alb_bastion" {
  type                      = "ingress"
  security_group_id         = local.backend_alb_sg_id# forntend SG_ID
  source_security_group_id  = local.bastion_sg_id# frontend LB SG_ID
  from_port                 = 80
  protocol                  = "tcp"
  to_port                   = 80
}


resource "aws_security_group_rule" "bastion_laptop" {
  type                      = "ingress"
  security_group_id         = local.bastion_sg_id  # forntend SG_ID
  cidr_blocks               = ["0.0.0.0/0"]# frontend LB SG_ID
  from_port                 = 22
  protocol                  = "tcp"
  to_port                   = 22
}

resource "aws_security_group_rule" "mongodb_bastion" {
  type                      = "ingress"
  security_group_id         = local.mongodb_sg_id  
  source_security_group_id  = local.bastion_sg_id
  from_port                 = 22
  protocol                  = "tcp"
  to_port                   = 22
}

resource "aws_security_group_rule" "redis_bastion" {
  type                      = "ingress"
  security_group_id         = local.redis_sg_id  
  source_security_group_id  = local.bastion_sg_id
  from_port                 = 22
  protocol                  = "tcp"
  to_port                   = 22
}

resource "aws_security_group_rule" "rabbitmq_bastion" {
  type                      = "ingress"
  security_group_id         = local.rabbitmq_sg_id 
  source_security_group_id  = local.bastion_sg_id
  from_port                 = 22
  protocol                  = "tcp"
  to_port                   = 22
}

resource "aws_security_group_rule" "mysql_bastion" {
  type                      = "ingress"
  security_group_id         = local.mysql_sg_id 
  source_security_group_id  = local.bastion_sg_id
  from_port                 = 22
  protocol                  = "tcp"
  to_port                   = 22
}

resource "aws_security_group_rule" "catalogue_bastion" {
  type                      = "ingress"
  security_group_id         = local.catalogue_sg_id 
  source_security_group_id  = local.bastion_sg_id
  from_port                 = 22
  protocol                  = "tcp"
  to_port                   = 22
}

resource "aws_security_group_rule" "mongodb_catalogue" {
  type                      = "ingress"
  security_group_id         = local.mongodb_sg_id 
  source_security_group_id  = local.catalogue_sg_id
  from_port                 = 27017
  protocol                  = "tcp"
  to_port                   = 27017
}


resource "aws_security_group_rule" "catalogue_backend_alb" {
  type                      = "ingress"
  security_group_id         = local.catalogue_sg_id 
  source_security_group_id  = local.backend_alb_sg_id
  from_port                 = 8080
  protocol                  = "tcp"
  to_port                   = 8080
}

resource "aws_security_group_rule" "user_bastion" {
  type                      = "ingress"
  security_group_id         = local.user_sg_id 
  source_security_group_id  = local.bastion_sg_id
  from_port                 = 22
  protocol                  = "tcp"
  to_port                   = 22
}

resource "aws_security_group_rule" "redis_user" {
  type                      = "ingress"
  security_group_id         = local.redis_sg_id 
  source_security_group_id  = local.user_sg_id
  from_port                 = 6379
  protocol                  = "tcp"
  to_port                   = 6379
}

resource "aws_security_group_rule" "user_backend_alb" {
  type                      = "ingress"
  security_group_id         = local.user_sg_id 
  source_security_group_id  = local.backend_alb_sg_id
  from_port                 = 8080
  protocol                  = "tcp"
  to_port                   = 8080
}