# main.tf

terraform {
  required_version = "0.12"
}

#####
##### IaaC for AWS, using shared credentials file in default location -- ~/.aws/credentials
#####

provider "aws" {
  version = "~> 2.12"
  region = "${var.aws_region}"
}

#####
##### Data sources to get default VPC and subnets IDs
#####

data "aws_vpc" "default" {
  default = true
}

data "aws_subnet_ids" "all" {
  vpc_id = "${data.aws_vpc.default.id}"
}

#####
##### Creating security groups
#####

resource "aws_security_group" "elb" {
  name        = "perimeter"
  description = "Security group for Internet access to the application"
  vpc_id      = "${data.aws_vpc.default.id}"

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

resource "aws_security_group" "ec2" {
  name        = "instances"
  description = "Security group for Internet access to EC2 instances"
  vpc_id      = "${data.aws_vpc.default.id}"

  ingress {
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

#####
##### Taking control over default security group to get it's ID and thus allow traffic between frontend and RDS
#####

resource "aws_default_security_group" "default" {
  vpc_id = "${data.aws_vpc.default.id}"

  ingress {
    protocol  = -1
    self      = true
    from_port = 0
    to_port   = 0
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}


#####
##### Creating key pair for EC2 instances access
#####

resource "aws_key_pair" "default" {
  key_name   = "test"
  public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDJK1q6NPJyvEz5hJgZZmsbxu5jezJc56h+2fFzhb8Xj5Ux0rY292q5MOIgnwq21PTy6FOOX1NdRNeO+b+SJU83b/WKphLFv5vp2kUlF+XUnvWV5tBq7xlTX33M3zHHTF9UYIubW3Rkkqufniu2kOd2Htsd+23rK/RDmk1zJY/lJcaf9pleW/ZldfQnv5DzzK+yefMdAGcsIj9v0p361MG4TDC1rracUBo2GHkYQy4IYhxy3hrPXHho6NjEl46Yifkowtv9J4pFpnv0K41NaZton83jhc3TylwJ/7dCk3bAJ21tNfqy0OeHxKiQat5Scnf8XhRLDlROq7vt61FWwD8x bofh@T470"
}

#####
##### Creating EC2 instances for frontend
#####

resource "aws_instance" "testfront" {

  count = 1

  instance_type          = "t2.micro"
  ami                    = "${var.ami}"
  key_name               = "test"
  vpc_security_group_ids = ["${aws_default_security_group.default.id}", "${aws_security_group.ec2.id}"]

  lifecycle {
    ignore_changes = ["private_ip", "root_block_device", "ebs_block_device"]
  }
}

#####
##### Creating ELB application load balancer
#####

resource "aws_elb" "testapp" {
  name = "testapp"

  subnets         = "${data.aws_subnet_ids.all.ids}"
  security_groups = ["${aws_default_security_group.default.id}", "${aws_security_group.elb.id}"]
  instances       = "${aws_instance.testfront.*.id}"

  listener {
    instance_port     = 80
    instance_protocol = "tcp"
    lb_port           = 80
    lb_protocol       = "tcp"
  }

  health_check {
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 3
    target              = "http:80/"
    interval            = 30
  }
}

#####
##### Creating RDS PosgtgreSQL instance
#####

resource "aws_db_instance" "default" {
  instance_class       = "db.t2.micro"
  allocated_storage    = 20
  engine               = "postgres"
  engine_version       = "11.2"
  username             = "postgres"
  password             = "${var.postgres_pwd}"
  skip_final_snapshot  = "true"   #################################### !!! for test purposes only !!!
}
