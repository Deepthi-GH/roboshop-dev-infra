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