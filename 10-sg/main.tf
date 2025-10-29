# module "catalogue" {  #open source module
#   source = "terraform-aws-modules/security-group/aws"

#   name        = "${local.common_name_suffix}-catalogue" #roboshop-dev-catalogue
#   use_name_prefix = false
#   description = "Security group for catalogue with custom ports open within VPC, egress all traffic"
#   vpc_id      =  data.aws_ssm_parameter.vpc_id.value
  
# }

module "sg" {
  source = "git::https://github.com/Deepthi-GH/terraform-aws-sg.git?ref=main"
  count = length(var.sg_names)
  project_name = var.project_name
  environment  = var.environment
  sg_name      = var.sg_names[count.index]
  sg_description = "created for ${var.sg_names[count.index]}"
  vpc_id       =  local.vpc_id
}

# # frontend accepting traffic from frontend LB.
# resource "aws_security_group_rule" "frontned_frontend_lb" {
#   type                      = "ingress"
#   security_group_id         = module.sg[9].sg_id # forntend SG_ID
#   source_security_group_id  = module.sg[11].sg_id # frontend LB SG_ID
#   from_port                 = 80
#   protocol                  = "tcp"
#   to_port                   = 80
# }
