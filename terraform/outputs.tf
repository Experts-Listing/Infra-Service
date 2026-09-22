output "aws_region" {
  value = var.aws_region
}

output "eks_cluster_name" {
  value = module.eks.cluster_name
}

output "ecr_registry" {
  value = split("/", aws_ecr_repository.service["frontend"].repository_url)[0]
}

output "ecr_repository_urls" {
  value = { for k, repo in aws_ecr_repository.service : k => repo.repository_url }
}

output "ci_push_role_arns" {
  description = "Set as AWS_ECR_PUSH_ROLE_ARN in each application repository"
  value       = { for k, role in aws_iam_role.ci : var.services[k] => role.arn }
}

output "cd_role_arn" {
  description = "Set as AWS_CD_ROLE_ARN in Infra-Service"
  value       = aws_iam_role.cd.arn
}

output "alarm_topic_arn" {
  value = aws_sns_topic.alarms.arn
}
