################################################################################
# Basic Example
# Simple EFS file system with mount targets in 2 AZs
#
# What gets created:
#   - 1 EFS file system (encrypted, bursting throughput)
#   - 2 Mount targets (one per AZ)
#   - 1 Security group (port 2049/TCP NFS)
#   - Backup policy (disabled in dev)
#   - TLS enforcement (always on)
#
# Auto-generated name: rohanmatre-dev-ap-south-1-efs
#
# After creation — mount on EC2 (Linux):
#   sudo yum install -y amazon-efs-utils
#   sudo mkdir /mnt/efs
#   sudo mount -t efs -o tls <efs-id>:/ /mnt/efs
################################################################################

provider "aws" {
  region = "ap-south-1"
}

module "vpc" {
  source  = "rohanmatre007dev-sys/vpc/rohanmatre"
  version = "1.0.0"

  environment     = "dev"
  private_subnets = ["10.0.11.0/24", "10.0.12.0/24"]
}

module "efs" {
  source = "../../"

  environment = "dev"

  # Security group — allow NFS from entire VPC CIDR
  security_group_vpc_id = module.vpc.vpc_id
  security_group_ingress_rules = {
    vpc_nfs = {
      description = "NFS from VPC private subnets"
      cidr_ipv4   = "10.0.0.0/16"
      from_port   = 2049
      to_port     = 2049
      ip_protocol = "tcp"
    }
  }

  # Mount targets — one per AZ
  mount_targets = {
    "ap-south-1a" = {
      subnet_id = module.vpc.private_subnet_ids[0]
    }
    "ap-south-1b" = {
      subnet_id = module.vpc.private_subnet_ids[1]
    }
  }
}
