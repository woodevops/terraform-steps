provider "aws" {
  region     = "us-east-1"
  access_key = "PUT IN YOUR KEY HERE"
  secret_key = "PUT IN YOUR KEY HERE"
}

/* resource "aws_instance" "my-hands-on-svr" {
  ami           = "ami-04505e74c0741db8d"
  instance_type = "t2.micro"
  tags = {
    Name = "ubuntu-svr"
  }
}  */




# resource "aws_vpc" "my-first-vpc1" {
#   cidr_block = "10.0.0.0/16"
#   tags = {
#     Name = "production"
#   }
# }


/* resource "aws_subnet" "subnet-1" {
  vpc_id     = aws_vpc.my-first-vpc1.id
  cidr_block = "10.0.1.0/24"

  tags = {
    Name = "prod-subnet"
  }
} */

# 1.create vpc
resource "aws_vpc" "project-a" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "project-agabus"
  }
}

# 2.create internet Gateway
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.project-a.id

}

# 3.create custom route Table
resource "aws_route_table" "project-a-Rtable" {
  vpc_id = aws_vpc.project-a.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  route {
    ipv6_cidr_block = "::/0"
    gateway_id      = aws_internet_gateway.gw.id
  }

  tags = {
    Name = "proj-a"
  }
}

# 4. Create a subnet
resource "aws_subnet" "subnet-a" {
  vpc_id            = aws_vpc.project-a.id
  cidr_block        = var.subnet_prefix
    availability_zone = "us-east-1a"

  tags = {
    Name = "proj-a-subnet"
  }
}


variable "subnet_prefix" {
  description = "cidr block for the subnet"
  type = any  
}

# 5.Associate subnet with route table
resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.subnet-a.id
  route_table_id = aws_route_table.project-a-Rtable.id
}

# 6.Create security group to allow port 22,80,443
resource "aws_security_group" "allow_web" {
  name        = "allow_web_traffic"
  description = "Allow web inbound traffic"
  vpc_id      = aws_vpc.project-a.id

  ingress {
    description      = "HTTPS"
    from_port        = 443
    to_port          = 443
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  ingress {
    description      = "HTTP"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  ingress {
    description      = "SSH"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }


  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "allow_web"
  }
}

# 7. Create network interface with an ip in the subnet from #4
resource "aws_network_interface" "web-server-nic" {
  subnet_id       = aws_subnet.subnet-a.id
  private_ips     = ["10.0.1.50"]
  security_groups = [aws_security_group.allow_web.id]
}

# 8. Assign an elastic IP to the network created in #7
resource "aws_eip" "one" {
  vpc                       = true
  network_interface         = aws_network_interface.web-server-nic.id
  associate_with_private_ip = "10.0.1.50"
  depends_on                = [aws_internet_gateway.gw]
}



# 9. Create Ubuntu server and install/Enable apache2

resource "aws_instance" "web-server-proj-a" {
  ami               = "ami-04505e74c0741db8d"
  instance_type     = "t2.micro"
  availability_zone = "us-east-1a"
  key_name          = "Terra-key"


  network_interface {
    device_index         = 0
    network_interface_id = aws_network_interface.web-server-nic.id
  }

  user_data = <<-EOF
            #!/bin/bash
            sudo apt update -y
            sudo apt install apache2 -y
            sudo systemctl start apache2
            sudo bash -c 'echo your very first web server > /var/www/html/index.html'
            EOF
  tags = {
    Name = "web-server"
  }
}

# 10. Useful outputs : these will display only on terrafom plan 

output "proj_a_public_ip" {
  value       = aws_eip.one.public_ip
  description = "The public IP address of the web server instance."
}

output "proj_a_private_ip" {
  value = aws_eip.one.private_ip

}


output "proj_a_server_id" {
  value = aws_instance.web-server-proj-a.id

}
