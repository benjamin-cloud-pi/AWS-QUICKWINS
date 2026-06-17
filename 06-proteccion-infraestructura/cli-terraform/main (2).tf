terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 5.0" }
  }
}

provider "aws" {
  region = var.region
}

variable "region" {
  type    = string
  default = "us-east-1"
}

variable "vpc_id" {
  description = "VPC donde crear el SG seguro"
  type        = string
}

variable "admin_cidr" {
  description = "CIDR permitido para administración. Ej: IP VPN /32"
  type        = string
  default     = "203.0.113.10/32"
}

resource "aws_security_group" "admin_access" {
  name        = "admin-access-restricted"
  description = "Acceso administrativo restringido"
  vpc_id      = var.vpc_id
  tags = { Name = "admin-access-restricted", ManagedBy = "terraform" }
}

resource "aws_vpc_security_group_ingress_rule" "ssh_restricted" {
  security_group_id = aws_security_group.admin_access.id
  description       = "SSH restringido a CIDR administrativo"
  ip_protocol       = "tcp"
  from_port         = 22
  to_port           = 22
  cidr_ipv4         = var.admin_cidr
}

resource "aws_vpc_security_group_ingress_rule" "rdp_restricted" {
  security_group_id = aws_security_group.admin_access.id
  description       = "RDP restringido a CIDR administrativo"
  ip_protocol       = "tcp"
  from_port         = 3389
  to_port           = 3389
  cidr_ipv4         = var.admin_cidr
}

resource "aws_vpc_security_group_egress_rule" "allow_all_outbound" {
  security_group_id = aws_security_group.admin_access.id
  description       = "Allow outbound"
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_iam_role" "ec2_ssm" {
  name = "EC2-SSM-SessionManager"
  assume_role_policy = jsonencode({ Version = "2012-10-17", Statement = [{ Effect = "Allow", Principal = { Service = "ec2.amazonaws.com" }, Action = "sts:AssumeRole" }] })
}

resource "aws_iam_role_policy_attachment" "ec2_ssm" {
  role       = aws_iam_role.ec2_ssm.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ec2_ssm" {
  name = "EC2-SSM-SessionManager"
  role = aws_iam_role.ec2_ssm.name
}

output "security_group_id" { value = aws_security_group.admin_access.id }
output "ssm_instance_profile" { value = aws_iam_instance_profile.ec2_ssm.name }
