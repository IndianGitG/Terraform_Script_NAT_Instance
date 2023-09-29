provider "aws" {
  region = "ap-northeast-1"  # Change this to your desired AWS region
}

resource "aws_vpc" "poc_vpc" {
  cidr_block = "10.0.0.0/16"
#   enable_dns_support = true
#   enable_dns_hostnames = true
  tags = {
    Name = "poc_vpc"
  }
}

resource "aws_subnet" "public_subnet" {
  vpc_id = aws_vpc.poc_vpc.id
  cidr_block = "10.0.0.0/24"
  availability_zone = "ap-northeast-1a"  # Change this to your desired availability zone
  map_public_ip_on_launch = true
  tags = {
    Name = "poc_public_subnet"
  }
}

resource "aws_subnet" "private_subnet" {
  vpc_id = aws_vpc.poc_vpc.id
  cidr_block = "10.0.1.0/24"
  availability_zone = "ap-northeast-1c"  # Change this to your desired availability zone
  tags = {
    Name = "poc_private_subnet"
  }
}

resource "aws_internet_gateway" "poc_igw" {
  vpc_id = aws_vpc.poc_vpc.id
  tags = {
    Name = "poc_igw"
  }
}

resource "aws_security_group" "poc_security_group" {
  name_prefix = "poc_security_group"
  vpc_id = aws_vpc.poc_vpc.id
  
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = [aws_subnet.private_subnet.cidr_block]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [aws_subnet.private_subnet.cidr_block]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = -1  # All ICMP - IPv4
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = [aws_subnet.private_subnet.cidr_block]
  }

  ingress {
    from_port   = 8080  # Custom rule for port 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = [aws_subnet.private_subnet.cidr_block]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = -1  # All ICMP - IPv4
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = ["0.0.0.0/0"]  # All ICMP traffic to anywhere
  }
}

resource "aws_route_table" "public_route_table" {
  vpc_id = aws_vpc.poc_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.poc_igw.id
  }

  tags = {
    Name = "poc_public_route_table"
  }
}

resource "aws_route_table_association" "public_subnet_association" {
  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.public_route_table.id
}

resource "aws_instance" "poc_ec2_instance" {
  ami           = "ami-0342c9aa06b2a6488"
  instance_type = "t4g.nano"
  key_name      = "thumsup"
  subnet_id     = aws_subnet.public_subnet.id
  security_groups = [aws_security_group.poc_security_group.id]
  source_dest_check = false

  iam_instance_profile = aws_iam_instance_profile.ssm_instance_profile.name

  tags = {
    Name = "poc-ec2-instance"
  }
}

# resource "aws_network_interface" "poc_network_interface" {
#   # Your network interface configuration here
#   subnet_id       = aws_subnet.public_subnet.id
# #   private_ips     = ["10.0.0.50"]
# #   security_groups = [aws_security_group.web.id]

#   attachment {
#     instance     = aws_instance.poc_ec2_instance.id
#     device_index = 1
#   }
# }


# resource "aws_network_interface_attachment" "poc_attachment" {
#   instance_id          = aws_instance.poc_ec2_instance.id
#   network_interface_id = aws_network_interface.poc_network_interface.id
# }

resource "aws_route_table" "private_route_table" {
  vpc_id = aws_vpc.poc_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    network_interface_id = aws_instance.poc_ec2_instance.primary_network_interface_id
  }

  tags = {
    Name = "poc_private_route_table"
  }
}

resource "aws_route_table_association" "private_subnet_association" {
  subnet_id      = aws_subnet.private_subnet.id
  route_table_id = aws_route_table.private_route_table.id
}

resource "aws_security_group" "poc_security_group2" {
  name_prefix = "poc_security_group2"
  vpc_id      = aws_vpc.poc_vpc.id
  
  // Inbound rule: Allow SSH from public subnet
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [aws_subnet.public_subnet.cidr_block]
  }

  // Outbound rule: Allow all traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  egress {
    from_port   = -1  # All ICMP - IPv4
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = ["0.0.0.0/0"]  # All ICMP traffic to anywhere
  }
}

resource "aws_instance" "poc_private_ec2_instance" {
  ami           = "ami-0342c9aa06b2a6488"
  instance_type = "t4g.nano"
  key_name      = "thumsup"
  subnet_id     = aws_subnet.private_subnet.id
  security_groups = [aws_security_group.poc_security_group2.id]

  iam_instance_profile = aws_iam_instance_profile.ssm_instance_profile.name

  tags = {
    Name = "poc-private-ec2-instance"
  }
}

resource "aws_iam_instance_profile" "ssm_instance_profile" {
  name = "SSMInstanceProfile"
  role = aws_iam_role.ssm_role.name
}

resource "aws_iam_role" "ssm_role" {
  name = "SSMRole"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_policy" "ssm_policy" {
  name = "SSMPolicy"
  description = "IAM policy for Systems Manager (Session Manager)"
  policy = jsonencode({
    # Version = "2012-10-17",
    # Statement = [
    #   {
    #     Action = [
    #       "ssm:DescribeSessions",
    #       "ssm:StartSession"
    #     ],
    #     Effect   = "Allow",
    #     Resource = "*"
    #   }
    # ]

    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "ssm:DescribeAssociation",
                "ssm:GetDeployablePatchSnapshotForInstance",
                "ssm:GetDocument",
                "ssm:DescribeDocument",
                "ssm:GetManifest",
                "ssm:GetParameter",
                "ssm:GetParameters",
                "ssm:ListAssociations",
                "ssm:ListInstanceAssociations",
                "ssm:PutInventory",
                "ssm:PutComplianceItems",
                "ssm:PutConfigurePackageResult",
                "ssm:UpdateAssociationStatus",
                "ssm:UpdateInstanceAssociationStatus",
                "ssm:UpdateInstanceInformation"
            ],
            "Resource": "*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "ssmmessages:CreateControlChannel",
                "ssmmessages:CreateDataChannel",
                "ssmmessages:OpenControlChannel",
                "ssmmessages:OpenDataChannel"
            ],
            "Resource": "*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "ec2messages:AcknowledgeMessage",
                "ec2messages:DeleteMessage",
                "ec2messages:FailMessage",
                "ec2messages:GetEndpoint",
                "ec2messages:GetMessages",
                "ec2messages:SendReply"
            ],
            "Resource": "*"
        }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ssm_policy_attachment" {
  policy_arn = aws_iam_policy.ssm_policy.arn
  role       = aws_iam_role.ssm_role.name
}
