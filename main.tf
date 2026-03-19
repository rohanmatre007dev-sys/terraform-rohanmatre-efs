################################################################################
# Wrapper calls the official upstream module
# Source: terraform-aws-modules/efs/aws
# Docs:   https://registry.terraform.io/modules/terraform-aws-modules/efs/aws
#
# This wrapper adds:
#   - Auto naming:          rohanmatre-{env}-{region}-efs
#   - Auto tagging:         Environment, Owner, GitHubRepo, ManagedBy
#   - Prod encryption:      auto-enabled in prod
#   - Prod backups:         AWS Backup auto-enabled in prod
#   - Prod lifecycle:       AFTER_30_DAYS to IA auto-set in prod (85% cheaper)
#   - Prod throughput:      elastic mode auto-set in prod (scales automatically)
#   - TLS enforcement:      deny_nonsecure_transport=true always
#   - SG auto-naming:       security group named after EFS resource
#
# EXAM KEY DIFFERENCES — EFS vs EBS vs S3:
#   EFS = shared NFS, multiple EC2, multi-AZ, Linux only, pay per GB used
#   EBS = block storage, one EC2, one AZ, Windows+Linux, pay per GB provisioned
#   S3  = object storage, REST API, global, any OS, pay per GB stored
################################################################################

module "efs" {
  source  = "terraform-aws-modules/efs/aws"
  version = ">= 1.0"

  ##############################################################################
  # General
  ##############################################################################
  create = var.create
  name   = local.name
  tags   = local.tags

  ##############################################################################
  # EFS File System Core
  # EXAM: EFS is REGIONAL by default (Standard storage class)
  # EXAM: One Zone = single AZ, 47% cheaper but no HA (set availability_zone_name)
  ##############################################################################
  availability_zone_name = var.availability_zone_name
  creation_token         = var.creation_token
  region                 = var.region

  ##############################################################################
  # Performance Mode
  # EXAM: Use generalPurpose for ALL new workloads (default)
  # EXAM: maxIO only if > 7000 client connections AND you need maximum aggregate throughput
  ##############################################################################
  performance_mode = var.performance_mode

  ##############################################################################
  # Throughput Mode
  # Auto-set to elastic in prod via locals
  # EXAM: elastic = best for variable workloads (auto scales up and down)
  # EXAM: bursting = good for dev/test (throughput tied to storage size)
  # EXAM: provisioned = fixed throughput regardless of storage (expensive)
  # EXAM: NEVER use provisioned unless you have very specific throughput SLAs
  ##############################################################################
  provisioned_throughput_in_mibps = var.provisioned_throughput_in_mibps
  throughput_mode                 = local.throughput_mode

  ##############################################################################
  # Encryption
  # Auto-enabled in prod via locals
  # EXAM: encrypted = data at rest using AES-256 via KMS
  # EXAM: TLS in transit = enforced via deny_nonsecure_transport policy below
  ##############################################################################
  encrypted   = local.encrypted
  kms_key_arn = var.kms_key_arn

  ##############################################################################
  # Lifecycle Policy
  # Auto-configured in prod via locals (AFTER_30_DAYS → IA)
  # EXAM: EFS Standard-IA = 85% cheaper than EFS Standard
  # EXAM: transition_to_primary_storage_class = AFTER_1_ACCESS moves back on read
  # EXAM: Valid transition_to_ia values: AFTER_7_DAYS through AFTER_365_DAYS
  ##############################################################################
  lifecycle_policy = local.lifecycle_policy

  ##############################################################################
  # Protection
  ##############################################################################
  protection = var.protection

  ##############################################################################
  # File System Policy
  # EXAM: deny_nonsecure_transport = forces TLS for all EFS connections
  # EXAM: EFS file system policy = resource-based policy on the file system itself
  ##############################################################################
  attach_policy                             = var.attach_policy
  bypass_policy_lockout_safety_check        = var.bypass_policy_lockout_safety_check
  deny_nonsecure_transport                  = var.deny_nonsecure_transport
  deny_nonsecure_transport_via_mount_target = var.deny_nonsecure_transport_via_mount_target
  override_policy_documents                 = var.override_policy_documents
  policy_statements                         = var.policy_statements
  source_policy_documents                   = var.source_policy_documents

  ##############################################################################
  # Mount Targets
  # EXAM: Mount target = network interface in a subnet for EFS access
  # EXAM: Create one mount target PER AZ for high availability
  # EXAM: Mount targets use port 2049/TCP (NFS protocol)
  # EXAM: DNS: fs-xxxx.efs.region.amazonaws.com
  # EXAM: Mount command: mount -t efs -o tls fs-xxxx:/ /mnt/efs
  ##############################################################################
  mount_targets = var.mount_targets

  ##############################################################################
  # Security Group
  # EXAM: EFS SG must allow 2049/TCP ingress from EC2 instance SG or CIDR
  # EXAM: EC2 instance SG must allow 2049/TCP egress to EFS SG
  ##############################################################################
  create_security_group          = var.create_security_group
  security_group_description     = local.security_group_description
  security_group_egress_rules    = var.security_group_egress_rules
  security_group_ingress_rules   = var.security_group_ingress_rules
  security_group_name            = local.security_group_name
  security_group_use_name_prefix = var.security_group_use_name_prefix
  security_group_vpc_id          = var.security_group_vpc_id

  ##############################################################################
  # Access Points
  # EXAM: Access points = named entry points with enforced POSIX identity
  # EXAM: Use with: Lambda (no OS to set UID/GID), ECS/Fargate tasks
  # EXAM: posix_user.uid + gid = override the UID/GID of the connecting process
  # EXAM: root_directory.path = restrict access point to a subdirectory
  ##############################################################################
  access_points = var.access_points

  ##############################################################################
  # Backup Policy
  # Auto-enabled in prod via locals
  # EXAM: EFS backup uses AWS Backup service
  # EXAM: Creates daily recovery points with 35-day default retention
  ##############################################################################
  create_backup_policy = var.create_backup_policy
  enable_backup_policy = local.enable_backup_policy

  ##############################################################################
  # Replication
  # EXAM: EFS replication = async replication to another region (DR)
  # EXAM: RPO = near-zero (continuous replication)
  # EXAM: RTO = minutes (promote replica to primary)
  ##############################################################################
  create_replication_configuration      = var.create_replication_configuration
  replication_configuration_destination = var.replication_configuration_destination
}
