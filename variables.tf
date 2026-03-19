################################################################################
# General
################################################################################

variable "create" {
  description = "Controls whether EFS and all resources will be created"
  type        = bool
  default     = true
}

variable "region" {
  description = "AWS region where EFS will be created"
  type        = string
  default     = "ap-south-1"
}

variable "environment" {
  description = "Deployment environment"
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "stage", "prod"], var.environment)
    error_message = "Environment must be one of: dev, stage, prod."
  }
}

variable "name" {
  description = "Name of the EFS file system. Auto-generated if null."
  type        = string
  default     = null
}

variable "tags" {
  description = "Additional tags merged with common tags applied to all resources"
  type        = map(string)
  default     = {}
}

################################################################################
# EFS File System Core
# EXAM: EFS = Elastic File System — fully managed NFS (Network File System)
# EXAM: EFS vs EBS:
#   EFS = shared across MULTIPLE instances + AZs (NFS, Linux only)
#   EBS = attached to ONE instance in ONE AZ (block storage)
# EXAM: EFS vs S3:
#   EFS = file system (mount and use like a disk, low latency)
#   S3  = object storage (REST API, high throughput, not mountable natively)
# EXAM: EFS is REGIONAL — available across all AZs in a region automatically
################################################################################

variable "creation_token" {
  description = "Unique token for idempotent EFS creation. Auto-generated if null."
  type        = string
  default     = null
}

variable "availability_zone_name" {
  description = "AZ name for One Zone storage class. Null = Regional (Standard) storage."
  type        = string
  default     = null
}

################################################################################
# Performance Mode
# EXAM: generalPurpose = default, <35000 clients, lower latency (use this 99% of time)
# EXAM: maxIO = legacy, higher throughput/IOPS for 100s of clients, higher latency
# EXAM: maxIO NOT compatible with Elastic throughput mode
################################################################################

variable "performance_mode" {
  description = "Performance mode: generalPurpose (default) or maxIO (legacy, higher latency)"
  type        = string
  default     = null
}

################################################################################
# Throughput Mode
# EXAM: bursting = throughput scales with storage size (default, cost-effective)
# EXAM: elastic  = automatically scales to workload demand (recommended for variable loads)
# EXAM: provisioned = set fixed MiB/s (expensive — ~$1500/month for 256 MiB/s)
# EXAM: bursting baseline = 50 KiB/s per GiB stored + burst credits
################################################################################

variable "throughput_mode" {
  description = "Throughput mode: bursting (default), elastic (recommended), or provisioned"
  type        = string
  default     = null
}

variable "provisioned_throughput_in_mibps" {
  description = "Provisioned throughput in MiB/s. Only used when throughput_mode=provisioned."
  type        = number
  default     = null
}

################################################################################
# Encryption
# EXAM: EFS encryption at rest uses KMS
# EXAM: Encryption in transit = mount with TLS (tls option in mount command)
# EXAM: encrypted=true is best practice — always encrypt file systems
################################################################################

variable "encrypted" {
  description = "Enable encryption at rest. Auto-enabled in prod via locals."
  type        = bool
  default     = true
}

variable "kms_key_arn" {
  description = "ARN of KMS key for encryption. Null = AWS managed key (aws/elasticfilesystem)."
  type        = string
  default     = null
}

################################################################################
# Lifecycle Policy
# EXAM: EFS lifecycle = transition files to IA (Infrequent Access) storage class
# EXAM: EFS-IA is 85% cheaper than EFS Standard for infrequently accessed files
# EXAM: transition_to_ia values: AFTER_7_DAYS, AFTER_14_DAYS, AFTER_30_DAYS,
#                                AFTER_60_DAYS, AFTER_90_DAYS, AFTER_180_DAYS, AFTER_270_DAYS, AFTER_365_DAYS
# EXAM: transition_to_primary_storage_class = move back when accessed (AFTER_1_ACCESS)
################################################################################

variable "lifecycle_policy" {
  description = "Lifecycle policy for IA transition (e.g. {transition_to_ia = 'AFTER_30_DAYS'})"
  type = object({
    transition_to_ia                    = optional(string)
    transition_to_archive               = optional(string)
    transition_to_primary_storage_class = optional(string)
  })
  default = {}
}

################################################################################
# Protection
################################################################################

variable "protection" {
  description = "File protection configuration (replication_overwrite)"
  type = object({
    replication_overwrite = optional(string)
  })
  default = null
}

################################################################################
# File System Policy
# EXAM: EFS resource policy = controls who can mount and access the file system
# EXAM: deny_nonsecure_transport = enforces TLS for all connections
################################################################################

variable "attach_policy" {
  description = "Attach a resource policy to the file system"
  type        = bool
  default     = true
}

variable "bypass_policy_lockout_safety_check" {
  description = "Bypass EFS policy lockout safety check (use with caution)"
  type        = bool
  default     = null
}

variable "deny_nonsecure_transport" {
  description = "Deny non-TLS connections to EFS — enforces encrypted in-transit"
  type        = bool
  default     = true
}

variable "deny_nonsecure_transport_via_mount_target" {
  description = "Use common policy to deny non-TLS when accessed via mount target"
  type        = bool
  default     = true
}

variable "policy_statements" {
  description = "Map of custom IAM policy statements for EFS file system policy"
  type = map(object({
    sid           = optional(string)
    actions       = optional(list(string))
    not_actions   = optional(list(string))
    effect        = optional(string)
    resources     = optional(list(string))
    not_resources = optional(list(string))
    principals = optional(list(object({
      type        = string
      identifiers = list(string)
    })))
    not_principals = optional(list(object({
      type        = string
      identifiers = list(string)
    })))
    conditions = optional(list(object({
      test     = string
      values   = list(string)
      variable = string
    })))
    condition = optional(list(object({
      test     = string
      values   = list(string)
      variable = string
    })))
  }))
  default = null
}

variable "source_policy_documents" {
  description = "List of IAM policy documents merged into the exported document"
  type        = list(string)
  default     = []
}

variable "override_policy_documents" {
  description = "List of IAM policy documents that override statements with same sid"
  type        = list(string)
  default     = []
}

################################################################################
# Mount Targets
# EXAM: Mount target = ENI in a subnet that EFS uses to serve NFS traffic
# EXAM: One mount target per AZ — create one per AZ for high availability
# EXAM: Mount target uses port 2049 (NFS)
# EXAM: Mount command: mount -t efs -o tls fs-xxxx:/ /mnt/efs
################################################################################

variable "mount_targets" {
  description = "Map of mount targets (one per AZ). Key = AZ name, value = {subnet_id = ...}"
  type = map(object({
    ip_address      = optional(string)
    ip_address_type = optional(string)
    ipv6_address    = optional(string)
    region          = optional(string)
    security_groups = optional(list(string), [])
    subnet_id       = string
  }))
  default = {}
}

################################################################################
# Security Group (auto-created by upstream module)
# EFS uses port 2049 (NFS) — ingress must allow 2049/TCP from EC2 instances
################################################################################

variable "create_security_group" {
  description = "Create a security group for EFS mount targets"
  type        = bool
  default     = true
}

variable "security_group_name" {
  description = "Name for the EFS security group"
  type        = string
  default     = null
}

variable "security_group_description" {
  description = "Description of the EFS security group"
  type        = string
  default     = null
}

variable "security_group_use_name_prefix" {
  description = "Use security_group_name as prefix"
  type        = bool
  default     = false
}

variable "security_group_vpc_id" {
  description = "VPC ID for the EFS security group. From rohanmatre-vpc-wrapper output."
  type        = string
  default     = null
}

variable "security_group_ingress_rules" {
  description = "Map of ingress rules for EFS SG. Default port 2049/TCP (NFS)."
  type = map(object({
    name                         = optional(string)
    cidr_ipv4                    = optional(string)
    cidr_ipv6                    = optional(string)
    description                  = optional(string)
    from_port                    = optional(number, 2049)
    ip_protocol                  = optional(string, "tcp")
    prefix_list_id               = optional(string)
    referenced_security_group_id = optional(string)
    region                       = optional(string)
    tags                         = optional(map(string), {})
    to_port                      = optional(number, 2049)
  }))
  default = {}
}

variable "security_group_egress_rules" {
  description = "Map of egress rules for EFS SG"
  type = map(object({
    name                         = optional(string)
    cidr_ipv4                    = optional(string)
    cidr_ipv6                    = optional(string)
    description                  = optional(string)
    from_port                    = optional(number, 2049)
    ip_protocol                  = optional(string, "tcp")
    prefix_list_id               = optional(string)
    referenced_security_group_id = optional(string)
    region                       = optional(string)
    tags                         = optional(map(string), {})
    to_port                      = optional(number, 2049)
  }))
  default = {}
}

################################################################################
# Access Points
# EXAM: Access points = application-specific entry points into EFS
# EXAM: Access points enforce: root directory, POSIX user/group identity
# EXAM: Used with Lambda, ECS, Fargate to give isolated access to subdirectories
# EXAM: posix_user = override OS user/group that accesses files
################################################################################

variable "access_points" {
  description = "Map of access point definitions to create"
  type = map(object({
    name = optional(string)
    tags = optional(map(string), {})
    posix_user = optional(object({
      gid            = number
      uid            = number
      secondary_gids = optional(list(number))
    }))
    root_directory = optional(object({
      path = optional(string)
      creation_info = optional(object({
        owner_gid   = number
        owner_uid   = number
        permissions = string
      }))
    }))
  }))
  default = {}
}

################################################################################
# Backup Policy
# EXAM: EFS backup = integrated with AWS Backup service
# EXAM: Backup creates recovery points in Backup vault
# EXAM: Enable backups in prod — protects against accidental deletion
################################################################################

variable "create_backup_policy" {
  description = "Create a backup policy resource"
  type        = bool
  default     = true
}

variable "enable_backup_policy" {
  description = "Enable automated backups via AWS Backup. Auto-enabled in prod."
  type        = bool
  default     = false
}

################################################################################
# Replication
# EXAM: EFS replication = automatic async replication to another region/AZ
# EXAM: RPO near zero — replication is continuous
# EXAM: Use for DR — failover to replica in another region
################################################################################

variable "create_replication_configuration" {
  description = "Create a replication configuration to another region"
  type        = bool
  default     = false
}

variable "replication_configuration_destination" {
  description = "Replication destination config (region, availability_zone_name, kms_key_id)"
  type = object({
    availability_zone_name = optional(string)
    file_system_id         = optional(string)
    kms_key_id             = optional(string)
    region                 = optional(string)
  })
  default = null
}
