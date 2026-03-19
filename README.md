# terraform-rohanmatre-efs

Terraform wrapper module for AWS EFS (Elastic File System) — built on top of [terraform-aws-modules/efs/aws](https://registry.terraform.io/modules/terraform-aws-modules/efs/aws).

This wrapper adds:
- **Auto naming** → `rohanmatre-{environment}-{region}-efs`
- **Auto tagging** → `Environment`, `Owner`, `GitHubRepo`, `ManagedBy`
- **Prod encryption** → auto-enabled in prod
- **Prod backups** → AWS Backup auto-enabled in prod
- **Prod lifecycle** → AFTER_30_DAYS → IA auto-set in prod (85% cheaper)
- **Prod throughput** → elastic mode auto-set in prod (scales automatically)
- **TLS enforcement** → `deny_nonsecure_transport=true` always on
- **SG auto-naming** → security group automatically named from EFS resource name

---

## EFS vs EBS vs S3 (EXAM)

| | EFS | EBS | S3 |
|---|---|---|---|
| Type | File (NFS) | Block | Object |
| Access | Multiple instances | Single instance | HTTP API |
| AZ scope | Regional (multi-AZ) | Single AZ | Global |
| OS | Linux only | Windows + Linux | Any |
| Protocol | NFS (port 2049) | Block device | REST/HTTPS |
| Pricing | Pay per GB used | Pay per GB provisioned | Pay per GB stored |
| Use case | Shared file storage | Boot volumes, databases | Backups, media, data lake |

---

## Dependencies

```hcl
security_group_vpc_id = module.vpc.vpc_id           # rohanmatre-vpc-wrapper
mount_targets = {
  "ap-south-1a" = { subnet_id = module.vpc.private_subnet_ids[0] }
  "ap-south-1b" = { subnet_id = module.vpc.private_subnet_ids[1] }
}
```

---

## Usage

### Basic (dev)

```hcl
module "efs" {
  source  = "rohanmatre007dev-sys/efs/rohanmatre"
  version = "1.0.0"

  environment           = "dev"
  security_group_vpc_id = module.vpc.vpc_id
  security_group_ingress_rules = {
    vpc_nfs = {
      description = "NFS from VPC"
      cidr_ipv4   = "10.0.0.0/16"
    }
  }
  mount_targets = {
    "ap-south-1a" = { subnet_id = module.vpc.private_subnet_ids[0] }
    "ap-south-1b" = { subnet_id = module.vpc.private_subnet_ids[1] }
  }
}
```

### Advanced (prod with access points + backups)

```hcl
module "efs" {
  source  = "rohanmatre007dev-sys/efs/rohanmatre"
  version = "1.0.0"

  environment           = "prod"
  security_group_vpc_id = module.vpc.vpc_id

  mount_targets = {
    "ap-south-1a" = { subnet_id = module.vpc.private_subnet_ids[0] }
    "ap-south-1b" = { subnet_id = module.vpc.private_subnet_ids[1] }
    "ap-south-1c" = { subnet_id = module.vpc.private_subnet_ids[2] }
  }

  access_points = {
    app_data = {
      posix_user     = { gid = 1001, uid = 1001 }
      root_directory = { path = "/app/data", creation_info = { owner_gid = 1001, owner_uid = 1001, permissions = "755" } }
    }
  }

  # Prod auto-sets: encrypted=true, backups=true, lifecycle=AFTER_30_DAYS, throughput=elastic
}
```

---

## Environment-Aware Behavior

| Setting | dev / stage | prod |
|---|---|---|
| Encryption | On by default (var default) | Auto-enforced |
| Backup policy | Off | Auto-enabled |
| Lifecycle to IA | Off | Auto: AFTER_30_DAYS (85% cheaper) |
| Throughput mode | bursting | Auto: elastic |
| TLS enforcement | Always on | Always on |

---

## Mounting on EC2 (Linux)

```bash
# Install EFS utils
sudo yum install -y amazon-efs-utils    # Amazon Linux
sudo apt-get install -y amazon-efs-utils # Ubuntu

# Create mount point
sudo mkdir /mnt/efs

# Mount with TLS
sudo mount -t efs -o tls <efs-id>:/ /mnt/efs

# Mount specific access point
sudo mount -t efs -o tls,accesspoint=<access-point-id> <efs-id>:/ /mnt/efs

# Persist across reboots (/etc/fstab)
echo '<efs-id>:/ /mnt/efs efs defaults,tls,_netdev 0 0' | sudo tee -a /etc/fstab
```

---

## Inputs

| Name | Description | Type | Default |
|---|---|---|---|
| `create` | Controls whether resources will be created | `bool` | `true` |
| `region` | AWS region | `string` | `"ap-south-1"` |
| `environment` | Environment: dev, stage, prod | `string` | `"dev"` |
| `name` | EFS name. Auto-generated if null. | `string` | `null` |
| `encrypted` | Encryption at rest. Auto in prod. | `bool` | `true` |
| `kms_key_arn` | KMS key ARN. Null = AWS managed. | `string` | `null` |
| `throughput_mode` | bursting, elastic, provisioned | `string` | `null` |
| `lifecycle_policy` | IA transition config. Auto in prod. | `object` | `{}` |
| `security_group_vpc_id` | VPC ID from vpc-wrapper | `string` | `null` |
| `security_group_ingress_rules` | NFS ingress rules (port 2049) | `map(object)` | `{}` |
| `mount_targets` | Map of AZ → subnet_id | `map(object)` | `{}` |
| `access_points` | Map of access point configs | `map(object)` | `{}` |
| `enable_backup_policy` | Enable AWS Backup. Auto in prod. | `bool` | `false` |
| `create_replication_configuration` | Enable cross-region replication | `bool` | `false` |
| `tags` | Additional tags | `map(string)` | `{}` |

Full list: [variables.tf](variables.tf)

---

## Outputs

| Name | Description | Consumed By |
|---|---|---|
| `id` | EFS file system ID | Mount commands, EC2 user data |
| `dns_name` | DNS name for mounting | Mount commands |
| `arn` | EFS ARN | IAM policies |
| `mount_targets` | Map of mount target attributes | Reference |
| `security_group_id` | SG ID | EC2 instance egress rules |
| `access_points` | Map of access point attributes | Lambda, ECS tasks |

---

## Notes

- EFS port is **2049/TCP** — ensure EC2 SG allows egress to EFS SG on 2049
- Mount targets must be in the **same VPC** as EC2 instances
- One mount target **per AZ** for high availability
- Upstream module: [terraform-aws-modules/efs/aws >= 1.0](https://registry.terraform.io/modules/terraform-aws-modules/efs/aws)
- Default region: `ap-south-1`

---

## Requirements

| Name | Version |
|---|---|
| terraform | >= 1.5.7 |
| aws | >= 6.28 |
