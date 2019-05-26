# variables.tf

variable "aws_region" {
  description = "Ireland"
  default = "eu-west-1"
}

variable "ami" {
  description = "Amazon Linux 2 AMI (HVM), SSD Volume Type"
  default = "ami-030dbca661d402413"
}

variable "postgres_pwd" {
  description = "PostgreSQL master user password, provide via ENV variable"
}
