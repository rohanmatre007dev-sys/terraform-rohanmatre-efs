################################################################################
# Advanced Example
# Production EFS with KMS encryption, lifecycle, access points, backups
#
# What gets created:
#   - 1 EFS file system (KMS encrypted, elastic throughput)
#   - 3 Mount targets (one per AZ — HA across all AZs)
#   - 1 Security group (NFS 2049 from private subnets)
#   - 2 Access points (app data + shared logs)
#   - Backup policy enabled (AWS Backup)
#   - Lifecycle: AFTER_30_DAYS → Standard-IA (85% cheaper)
#   - TLS enforcement (deny_nonsecure_transport=true)
#
# Prod auto-sets:
#   - encrypted = true
#   - enable_backup_policy = true
#   - lifecycle_policy = { transition_to_ia = "AFTER_30_DAYS" }
#   - throughput_mode = "elastic"
################################################################################

provider "aws" {
  region = "ap-south-1"
}

module "vpc" {
  source  = "rohanmatre007dev-sys/vpc/rohanmatre"
  version = "1.0.0"

  environment     = "prod"
  cidr            = "10.10.0.0/16"
  public_subnets  = ["10.10.1.0/24", "10.10.2.0/24", "10.10.3.0/24"]
  private_subnets = ["10.10.11.0/24", "10.10.12.0/24", "10.10.13.0/24"]
}

module "efs" {
  source = "../../"

  name        = "rohanmatre-prod-shared-efs"
  environment = "prod"

  # KMS encryption — overrides prod default (aws/elasticfilesystem managed key)
  encrypted   = true
  kms_key_arn = "arn:aws:kms:ap-south-1:123456789012:key/your-kms-key-id"

  # Security group — allow NFS only from private subnet CIDRs
  security_group_vpc_id = module.vpc.vpc_id
  security_group_ingress_rules = {
    private_subnet_1 = {
      description = "NFS from private subnet AZ-a"
      cidr_ipv4   = "10.10.11.0/24"
    }
    private_subnet_2 = {
      description = "NFS from private subnet AZ-b"
      cidr_ipv4   = "10.10.12.0/24"
    }
    private_subnet_3 = {
      description = "NFS from private subnet AZ-c"
      cidr_ipv4   = "10.10.13.0/24"
    }
  }

  # Mount targets — one per AZ for full HA
  mount_targets = {
    "ap-south-1a" = { subnet_id = module.vpc.private_subnet_ids[0] }
    "ap-south-1b" = { subnet_id = module.vpc.private_subnet_ids[1] }
    "ap-south-1c" = { subnet_id = module.vpc.private_subnet_ids[2] }
  }

  # Access points — isolated entry points per application
  access_points = {
    # App data access point — enforces UID/GID 1001 (app user)
    app_data = {
      name = "app-data"
      posix_user = {
        gid = 1001
        uid = 1001
      }
      root_directory = {
        path = "/app/data"
        creation_info = {
          owner_gid   = 1001
          owner_uid   = 1001
          permissions = "755"
        }
      }
      tags = { Purpose = "app-data" }
    }

    # Shared logs access point — enforces UID/GID 1002 (logging service)
    shared_logs = {
      name = "shared-logs"
      posix_user = {
        gid = 1002
        uid = 1002
      }
      root_directory = {
        path = "/shared/logs"
        creation_info = {
          owner_gid   = 1002
          owner_uid   = 1002
          permissions = "750"
        }
      }
      tags = { Purpose = "shared-logs" }
    }
  }

  # Prod auto-sets:
  #   enable_backup_policy = true        (AWS Backup daily snapshots)
  #   lifecycle_policy = AFTER_30_DAYS   (85% cheaper for cold files)
  #   throughput_mode  = elastic         (scales automatically)
  #   encrypted        = true

  tags = {
    Project   = "rohanmatre-platform"
    DataClass = "shared-storage"
  }
}
