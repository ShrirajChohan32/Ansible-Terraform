#defining the provider block
provider "aws" {
  region  = "ap-southeast-2"
  profile = "default"
}

#Creating key to ssh into an Ec2 instance.
resource "tls_private_key" "dev_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "generated_key" {
  key_name   = var.generated_key_name
  public_key = tls_private_key.dev_key.public_key_openssh

  provisioner "local-exec" { # Generate "terraform-key-pair.pem" in current directory
    command = <<-EOT
      echo '${tls_private_key.dev_key.private_key_pem}' > ./'${var.generated_key_name}'.pem
      chmod 400 ./'${var.generated_key_name}'.pem
    EOT
  }
}

#Security group
resource "aws_security_group" "aws_sg" {
  depends_on = [aws_key_pair.generated_key]
  name       = "aws_sg"

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]

  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

#ec2 instance
resource "aws_instance" "webserver" {
  depends_on      = [aws_security_group.aws_sg]
  ami             = "ami-06a524880a10d79ba"
  instance_type   = "t2.micro"
  security_groups = ["aws_sg"]
  key_name        = var.generated_key_name
  tags = {
    Name = "TerraformAnsible"
  }
}

resource "null_resource" "nullremote2" {
  depends_on = [aws_instance.webserver]
  provisioner "local-exec" {
    command = "sleep 40;"

  }

}

#Fetching AWS Instance IP
output "op1" {
  value = aws_instance.webserver.public_ip

}

#IP of aws_instance copied to ip.txt 
resource "local_file" "ip" {
  content    = aws_instance.webserver.public_ip
  depends_on = [null_resource.nullremote2]
  filename   = "ip.txt"
  provisioner "local-exec" {
    environment = {
      ANSIBLE_PRIVATE_KEY_FILE = "${var.generated_key_name}.pem"
    }
    command = "ansible-playbook instance.yml"

  }
}

#Automatically opens webpage on Chrome on your local computer.
resource "null_resource" "nullremote1" {
  depends_on = [local_file.ip]
  provisioner "local-exec" {
    command = "open -a 'google chrome' http://${aws_instance.webserver.public_ip}"
  }
}