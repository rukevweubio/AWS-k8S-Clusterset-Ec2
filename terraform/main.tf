resource "aws_key_pair" "deployer" {
    key_name   = "my-local-key"
    public_key = file("id_rsa.pub.pem")
}

resource "aws_vpc" "main" {
    cidr_block           = var.vpc_cidr
    enable_dns_support   = true
    enable_dns_hostnames = true
    tags = {
        Name = "main-vpc"
    }
}

resource "aws_subnet" "main" {
    vpc_id                  = aws_vpc.main.id
    cidr_block              = var.subnet_cidr
    availability_zone       = var.availability_zone
    map_public_ip_on_launch = true
    tags = {
        Name = "main-subnet"
    }
}

resource "aws_internet_gateway" "main" {
    vpc_id = aws_vpc.main.id
    tags = {
        Name = "main-igw"
    }
}

resource "aws_route_table" "main" {
    vpc_id = aws_vpc.main.id
    route {
        cidr_block = "0.0.0.0/0"
        gateway_id = aws_internet_gateway.main.id
    }
    tags = {
        Name = "main-rt"
    }
}

resource "aws_route_table_association" "main" {
    subnet_id      = aws_subnet.main.id
    route_table_id = aws_route_table.main.id
}

resource "aws_iam_role" "cloudwatch_role" {
    name = "ec2-cloudwatch-role"

    assume_role_policy = jsonencode({
        Version = "2012-10-17"
        Statement = [
            {
                Effect = "Allow"
                Principal = {
                    Service = "ec2.amazonaws.com"
                }
                Action = "sts:AssumeRole"
            }
        ]
    })
}

resource "aws_iam_role_policy_attachment" "cloudwatch_policy" {
    role       = aws_iam_role.cloudwatch_role.name
    policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

resource "aws_iam_instance_profile" "cloudwatch_instance_profile" {
    name = "ec2-cloudwatch-instance-profile"
    role = aws_iam_role.cloudwatch_role.name
}

resource "aws_security_group" "master_sg" {
    name        = "k8s-master-sg"
    description = "Security group for Kubernetes master node"
    vpc_id      = aws_vpc.main.id

    ingress {
        description = "SSH"
        from_port   = 22
        to_port     = 22
        protocol    = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    ingress {
        description = "Kubernetes API server"
        from_port   = 6443
        to_port     = 6443
        protocol    = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    egress {
        from_port   = 0
        to_port     = 0
        protocol    = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }

    tags = {
        Name = "k8s-master-sg"
    }
}

resource "aws_security_group" "worker_sg" {
    name        = "k8s-worker-sg"
    description = "Security group for Kubernetes worker node"
    vpc_id      = aws_vpc.main.id

    ingress {
        description = "SSH"
        from_port   = 22
        to_port     = 22
        protocol    = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    ingress {
        description = "Kubelet API"
        from_port   = 10250
        to_port     = 10250
        protocol    = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    egress {
        from_port   = 0
        to_port     = 0
        protocol    = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }

    tags = {
        Name = "k8s-worker-sg"
    }
}

resource "aws_instance" "K8_master" {
    ami                         = var.ami_id
    instance_type               = var.master_instance_type
    subnet_id                   = aws_subnet.main.id
    vpc_security_group_ids      = [aws_security_group.master_sg.id]
    associate_public_ip_address = true
    key_name                    = aws_key_pair.deployer.key_name
    iam_instance_profile        = aws_iam_instance_profile.cloudwatch_instance_profile.name

    user_data = <<-EOF
        #!/bin/bash
        apt update -y
        apt install -y unzip wget
        wget https://s3.amazonaws.com/amazoncloudwatch-agent/ubuntu/amd64/latest/amazon-cloudwatch-agent.deb
        dpkg -i amazon-cloudwatch-agent.deb

        cat <<EOT > /opt/aws/amazon-cloudwatch-agent/bin/config.json
        {
            "agent": {
                "metrics_collection_interval": 60,
                "logfile": "/var/log/amazon-cloudwatch-agent.log"
            },
            "metrics": {
                "append_dimensions": {
                    "InstanceId": "{instance_id}"
                },
                "metrics_collected": {
                    "cpu": { "measurement": ["usage_system", "usage_user", "usage_idle"], "metrics_collection_interval": 60 },
                    "mem": { "measurement": ["mem_used_percent"], "metrics_collection_interval": 60 },
                    "disk": { "measurement": ["used_percent"], "metrics_collection_interval": 60 }
                }
            }
        }
        EOT

        systemctl enable amazon-cloudwatch-agent
        systemctl start amazon-cloudwatch-agent
    EOF

    tags = {
        Name = "K8_master"
    }
}

resource "aws_instance" "K8_worker" {
    ami                         = var.ami_id
    instance_type               = var.worker_instance_type
    subnet_id                   = aws_subnet.main.id
    vpc_security_group_ids      = [aws_security_group.worker_sg.id]
    associate_public_ip_address = true
    key_name                    = aws_key_pair.deployer.key_name
    iam_instance_profile        = aws_iam_instance_profile.cloudwatch_instance_profile.name

    user_data = <<-EOF
        #!/bin/bash
        apt update -y
        apt install -y unzip wget
        wget https://s3.amazonaws.com/amazoncloudwatch-agent/ubuntu/amd64/latest/amazon-cloudwatch-agent.deb
        dpkg -i amazon-cloudwatch-agent.deb

        cat <<EOT > /opt/aws/amazon-cloudwatch-agent/bin/config.json
        {
            "agent": {
                "metrics_collection_interval": 60,
                "logfile": "/var/log/amazon-cloudwatch-agent.log"
            },
            "metrics": {
                "append_dimensions": {
                    "InstanceId": "{instance_id}"
                },
                "metrics_collected": {
                    "cpu": { "measurement": ["usage_system", "usage_user", "usage_idle"], "metrics_collection_interval": 60 },
                    "mem": { "measurement": ["mem_used_percent"], "metrics_collection_interval": 60 },
                    "disk": { "measurement": ["used_percent"], "metrics_collection_interval": 60 }
                }
            }
        }
        EOT

        systemctl enable amazon-cloudwatch-agent
        systemctl start amazon-cloudwatch-agent
    EOF

    tags = {
        Name = "K8_worker"
    }
}
