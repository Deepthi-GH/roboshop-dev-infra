locals {
    ami_id              = data.aws_ami.joindevops.id
    common_name_suffix  = "${var.project_name}-${var.environment}" #roboshop-dev
    vpc_id              = data.aws_ssm_parameter.vpc_id.value
    catalogue_sg_id     = data.aws_ssm_parameter.catalogue_sg_id.value
    user_sg_id          = data.aws_ssm_parameter.user_sg_id.value
    private_subnet_id   = split("," ,data.aws_ssm_parameter.private_subnet_ids.value)[0]
    private_subnet_ids  = split("," ,data.aws_ssm_parameter.private_subnet_ids.value)
    backend_alb_listener_arn = data.aws_ssm_parameter.backend_alb_listener_arn.value
    common_tags         = {
        Project     = var.project_name
        Environment = var.environment
        Terraform   = "true"
    }
}