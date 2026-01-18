output "cd_user_arn" {
  value = aws_iam_user.cd_user.arn
}

output "ecr_api_repo_uri" {
  value       = aws_ecr_repository.api.repository_url
  description = "ECR Repository URI for the API"
}

output "ecr_nginx_repo_uri" {
  value       = aws_ecr_repository.nginx.repository_url
  description = "ECR Repository URI for Nginx"
}


