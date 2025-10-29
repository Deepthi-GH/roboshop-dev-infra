resource "aws_instance" "mongodb" {
  ami                    = local.ami_id
  instance_type          = "t3.micro"
  vpc_security_group_ids = [local.mongodb_sg_id]
  subnet_id              = local.database_subnet_ids
  tags = merge (
    local.common_tags,
    {
        Name = "${local.common_name_suffix}-mongodb" #roboshop-dev-mongodb
    }
  )
}

resource "terraform_data" "mongodb" {
  triggers_replace = [
    aws_instance.mongodb.id
  ]
  
connection {
    type     = "ssh"
    user     = "ec2-user"
    password = "DevOps321"
    host     = aws_instance.mongodb.private_ip
  }
  
  # terrarform copies this file to mongodb server
  provisioner "file" {
    source      = "bootstrap.sh"
    destination = "/tmp/bootstarp.sh"
  }

  provisioner "remote-exec" {
    inline = [
        "chmod +x /tmp/bootstarp.sh",
         "sudo sh /tmp/bootstarp.sh"
    ]
  }
}