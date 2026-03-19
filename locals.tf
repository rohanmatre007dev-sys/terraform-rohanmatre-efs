locals {
  ##############################################################################
  # Naming
  # Pattern: rohanmatre-{environment}-{region}-efs
  # Example: rohanmatre-dev-ap-south-1-efs
  ##############################################################################
  local_name = "rohanmatre-${var.environment}-${var.region}-efs"
  name       = var.name == null ? local.local_name : var.name

  ##############################################################################
  # Environment-Aware Logic
  # EXAM: Prod EFS should always have:
  #   - Encryption enabled (data at rest + enforce TLS in transit)
  #   - Backup policy enabled (AWS Backup integration)
  #   - Lifecycle policy set (cost savings via IA storage class)
  #   - Mount targets in ALL AZs (high availability)
  ##############################################################################
  is_prod = var.environment == "prod"

  # Encryption — always on in prod
  encrypted = local.is_prod ? true : var.encrypted

  # Backup — auto-enable in prod
  enable_backup_policy = local.is_prod ? true : var.enable_backup_policy

  # Lifecycle policy — auto-set in prod if not configured (30 days to IA)
  # EXAM: transition_to_ia=AFTER_30_DAYS saves ~85% on infrequently accessed files
  lifecycle_policy = local.is_prod && length(keys(var.lifecycle_policy)) == 0 ? {
    transition_to_ia                    = "AFTER_30_DAYS"
    transition_to_primary_storage_class = "AFTER_1_ACCESS"
  } : var.lifecycle_policy

  # Throughput mode — elastic in prod (scales automatically)
  # bursting is fine for dev
  throughput_mode = local.is_prod && var.throughput_mode == null ? "elastic" : var.throughput_mode

  # Security group name — auto-derive from EFS name
  security_group_name = var.security_group_name == null ? "${local.name}-sg" : var.security_group_name

  # Security group description — auto-derive
  security_group_description = var.security_group_description == null ? "EFS security group for ${local.name} — allows NFS port 2049 from VPC" : var.security_group_description

  ##############################################################################
  # Common Tags
  ##############################################################################
  common_tags = {
    Environment = var.environment
    Owner       = "rohanmatre"
    GitHubRepo  = "terraform-rohanmatre-efs"
    ManagedBy   = "terraform"
  }

  tags = merge(local.common_tags, var.tags, { Name = local.name })
}
