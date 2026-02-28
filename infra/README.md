## Start the project
```sh
docker image inspect hashicorp/terraform:1.13.3 \
  --format 'Entrypoint: {{.Config.Entrypoint}} Cmd: {{.Config.Cmd}}'
## Entrypoint: [/bin/terraform] Cmd: []

# get a shell into the terraform image
docker compose run --rm --entrypoint sh tf

```

run terraform commands
```sh
cd deploy

terraform init
terraform validate
terraform fmt
terraform apply --auto-approve
terraform destroy --auto-approve
```

We can also investigate data on console
```sh
terraform console

# in terraform console:
data.aws_region.current.name

```

## EC2

### user-data

```sh
terraform taint aws_instance.private_instance
terraform apply
```

@TODO: fix user-data (specific version of psql for example.)

```sh
# user_data = <<-EOF
# #!/bin/bash
# set -eux

# apt-get update -y
# apt-get install -y postgresql-client curl

# echo "User data completed" > /tmp/user_data_done.txt
# EOF

# user_data_replace_on_change = true
```

### SSM
```sh
aws ssm start-session --target <private-instance-id>

which psql
psql --version

```

now test
```sh
# outbound access
curl -i example.com

H_=<rds-endpoint>
psql -h $H_ -U admino -d watchlistdb

```



## ECS:

two tests:
- trust policy
- security group ingress 

### Trust Policy

just for fun if you 
```tf
data "aws_iam_policy_document" "ecs_assume_role" {
  statement {
    effect = "Allow"

    principals {
      type = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

```
you'll get sth like:
service xyz failed to launch a task with (error ECS was unable to assume the role 'arn:aws:iam::----' that was provided for this task. Please verify that the role being passed has the proper **trust relationship** and permissions and that your IAM user has permissions to pass this role.).
