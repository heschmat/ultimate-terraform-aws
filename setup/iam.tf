resource "aws_iam_user" "cd_user" {
  name = "${var.project_name}-cd-user"
  path = "/system/"
}

# resource "aws_iam_user_policy_attachment" "cd_user_attach" {
#   user       = aws_iam_user.cd_user.name
#   policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
# }

# resource "aws_iam_access_key" "cd_user_key" {
#   user = aws_iam_user.cd_user.name
# }

# output "cd_user_access_key_id" {
#   value       = aws_iam_access_key.cd_user_key.id
#   description = "Access Key ID for the CD user"
# }

# output "cd_user_secret_access_key" {
#   value       = aws_iam_access_key.cd_user_key.secret
#   description = "Secret Access Key for the CD user"
#   sensitive   = true
# }


# resource "aws_iam_role" "cd_role" {
#   name               = "${var.project_name}-cd-role-${var.environ}"
#   assume_role_policy = data.aws_iam_policy_document.cd_assume_role_policy.json
# }
# data "aws_iam_policy_document" "cd_assume_role_policy" {
#   statement {
#     effect = "Allow"

#     principals {
#       type        = "AWS"
#       identifiers = [aws_iam_user.cd_user.arn]
#     }

#     actions = ["sts:AssumeRole"]
#   }
# }
# resource "aws_iam_role_policy_attachment" "cd_role_attach" {
#   role       = aws_iam_role.cd_role.name
#   policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
# }
# output "cd_role_arn" {
#   value       = aws_iam_role.cd_role.arn
#   description = "ARN of the CD Role"
# }
