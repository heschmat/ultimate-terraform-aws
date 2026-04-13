output "vpc_id" {
  value = aws_vpc.main.id
}

# output "public_subnet_ids" {
#   value = aws_subnet.public[*].id
# }

output "ssm_box_id" {
  value = aws_instance.ssm_box.id
}

output "postgres_address" {
  value = local.postgres_instance.address
}

output "postgres_port" {
  value = local.postgres_instance.port
}

output "postgres_secret_arn" {
  value = local.postgres_instance.master_user_secret[0].secret_arn
}

# alb outputs -----
output "alb_dns_name" {
  value = aws_lb.ecs.dns_name
}
