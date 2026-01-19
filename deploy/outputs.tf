output "account_id" {
  value = data.aws_caller_identity.current.account_id
}

output "region" {
  value = data.aws_region.current.id
}

output "vpc_id" {
  value = aws_vpc.main.id
}

output "public_subnet_ids" {
  value = aws_subnet.public_subnets[*].id
}

output "private_subnet_ids" {
  value = aws_subnet.private_subnets[*].id
}

# output "eip_public_ips" {
#   value = aws_eip.nat[*].public_ip
# }


# alb outputs ----------------------
output "alb_dns_name" {
  value = aws_lb.ecs.dns_name
}

output "alb_arn" {
  value = aws_lb.ecs.arn
}

# ecs outputs ----------------------
# Output the ECS Cluster Name
output "ecs_cluster_name" {
  value = aws_ecs_cluster.main.name
}

# Output the ECS Service Name
output "ecs_service_name" {
  value = aws_ecs_service.app.name
}

# Output the ECS Task Definition ARN
output "ecs_task_definition_arn" {
  value = aws_ecs_task_definition.app.arn
}

# s3 bucket output ----------------------
output "s3_bucket_name" {
  value = aws_s3_bucket.static.bucket
}

# cloudfront output ----------------------
output "cloudfront_domain_name" {
  value = aws_cloudfront_distribution.static.domain_name
}

output "cloudfront_distribution_id" {
  value = aws_cloudfront_distribution.static.id
}
