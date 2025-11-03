resource "aws_instance" "bastion" {
  ami                    = local.ami_id
  instance_type          = "t3.micro"
  vpc_security_group_ids = [local.bastion_sg_id]
  subnet_id              = local.public_subnet_ids
  iam_instance_profile   = aws_iam_instance_profile.bastion.name
  user_data              = file("bastion.sh")
  tags = merge (
    local.common_tags,
    {
        Name = "${var.project_name}-${var.environment}-bastion"
    }
  ) 
}

# no need to run aws configure and terraform installation manuaaly
resource "aws_iam_instance_profile" "bastion" { 
      name = "bastion"
      role = "BastionTerraformAdmin"

  }