#!/bin/bash
set -euo pipefail
REGION=${AWS_REGION:-us-east-1}

echo "=== SSH 22 abierto a 0.0.0.0/0 ==="
aws ec2 describe-security-groups --region "$REGION"   --filters Name=ip-permission.from-port,Values=22             Name=ip-permission.to-port,Values=22             Name=ip-permission.cidr,Values=0.0.0.0/0   --query 'SecurityGroups[].{GroupId:GroupId,Name:GroupName,VpcId:VpcId}'   --output table

echo "=== RDP 3389 abierto a 0.0.0.0/0 ==="
aws ec2 describe-security-groups --region "$REGION"   --filters Name=ip-permission.from-port,Values=3389             Name=ip-permission.to-port,Values=3389             Name=ip-permission.cidr,Values=0.0.0.0/0   --query 'SecurityGroups[].{GroupId:GroupId,Name:GroupName,VpcId:VpcId}'   --output table

echo "=== All traffic abierto a 0.0.0.0/0 ==="
aws ec2 describe-security-groups --region "$REGION"   --filters Name=ip-permission.protocol,Values=-1             Name=ip-permission.cidr,Values=0.0.0.0/0   --query 'SecurityGroups[].{GroupId:GroupId,Name:GroupName,VpcId:VpcId}'   --output table

# Remediación manual ejemplo:
# aws ec2 revoke-security-group-ingress --group-id sg-xxxxxxxx --protocol tcp --port 22 --cidr 0.0.0.0/0
