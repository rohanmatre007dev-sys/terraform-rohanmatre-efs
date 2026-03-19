################################################################################
# EFS File System Outputs
################################################################################

output "id" {
  description = "EFS file system ID (e.g. fs-ccfc0d65) — use in mount commands"
  value       = module.efs.id
}

output "arn" {
  description = "ARN of the EFS file system — use in IAM policies"
  value       = module.efs.arn
}

output "dns_name" {
  description = "DNS name for mounting: fs-xxxx.efs.region.amazonaws.com"
  value       = module.efs.dns_name
}

output "size_in_bytes" {
  description = "Latest metered size in bytes of data stored in the file system"
  value       = module.efs.size_in_bytes
}

################################################################################
# Mount Target Outputs
# Consumed by: EC2 instances and ECS tasks that need to mount the file system
################################################################################

output "mount_targets" {
  description = "Map of mount targets and their attributes (id, dns_name, ip_address per AZ)"
  value       = module.efs.mount_targets
}

################################################################################
# Security Group Outputs
# Consumed by: EC2 instance SG rules — allow 2049/TCP egress to EFS SG
################################################################################

output "security_group_id" {
  description = "ID of the EFS security group — add as source in EC2 instance SG egress rules"
  value       = module.efs.security_group_id
}

output "security_group_arn" {
  description = "ARN of the EFS security group"
  value       = module.efs.security_group_arn
}

################################################################################
# Access Points
################################################################################

output "access_points" {
  description = "Map of access points and their attributes (id, arn, file_system_id)"
  value       = module.efs.access_points
}

################################################################################
# Replication
################################################################################

output "replication_configuration_destination_file_system_id" {
  description = "File system ID of the replica (in the destination region)"
  value       = module.efs.replication_configuration_destination_file_system_id
}
