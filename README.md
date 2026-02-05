# ultimate-terraform-aws

## Terraform `.gitignore`
To avoid committing sensitive files and local Terraform artifacts, make sure your `.gitignore` includes the official Terraform rules.
You can use GitHub's recommended Terraform `.gitignore`:

👉 https://github.com/github/gitignore/blob/main/Terraform.gitignore


## run Terraform commands
We'll be using docker-compose & Makefile to enhance the flow.

```sh
# sample command
make setup-init

```


```sh

docker compose run --rm tf -chdir=deploy init -migrate-state


# ⚠️ -reconfigure does not migrate state. It just accepts the new config.
# use it when:
# You don't care about existing state
# Or this repo has never been applied
# Or you intentionally want Terraform to forget the old backend entirely
docker compose run --rm tf -chdir=deploy init -reconfigure
```

## network

### public subnet

```sh
# verify outbound internet access (most important)
curl -I https://example.com
## HTTP/2 200



```

### private subnet

Install Session Manager Plugin
```sh
curl "https://s3.amazonaws.com/session-manager-downloads/plugin/latest/ubuntu_64bit/session-manager-plugin.deb" \
  -o session-manager-plugin.deb

sudo dpkg -i session-manager-plugin.deb

# verify installation
session-manager-plugin
## The Session Manager plugin was installed successfully. Use the AWS CLI to start a session.

# replace the instance id:
aws ssm start-session --target i-0a7c4440a317df48f
## Starting session with SessionId: ...

sudo systemctl status amazon-ssm-agent
## active (running)
```

Verify the network:
```sh
curl -s ifconfig.me || echo "no public egress"
# If this prints an IP → NAT or egress works
# If it hangs/fails → no internet egress (still OK if using VPC endpoints)

curl -I https://example.com/
## HTTP/2 200
```

Check whether the instance has an IAM role:
```sh
curl http://169.254.169.254/latest/meta-data/iam/info
## get nothing?

# On Amazon Linux 2023, IMDSv2 is strict by default.
# IMDSv2 requires a session token.

TOKEN=$(curl -X PUT "http://169.254.169.254/latest/api/token" \
  -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")

curl -H "X-aws-ec2-metadata-token: $TOKEN" \
  http://169.254.169.254/latest/meta-data/iam/info


```

#### ddx

```sh
aws ec2 describe-instances \
  --instance-ids i-0a7c4440a317df48f \
  --query 'Reservations[0].Instances[0].IamInstanceProfile'

# aws iam list-attached-role-policies --role-name <role-name>
aws iam list-attached-role-policies --role-name watchlist-api-dev-ssm-role

# check the route table for the private subnets
aws ec2 describe-route-tables \
  --filters Name=association.subnet-id,Values=subnet-0f650b26dcffcc17a \
  --query 'RouteTables[0].Routes'

```


## rds

```sh
# filter to what exact engine your instance class supports:
aws rds describe-orderable-db-instance-options \
  --engine postgres \
  --db-instance-class db.t3.micro \
  --query "OrderableDBInstanceOptions[].EngineVersion" \
  --output table

```

Verify
```sh
aws ssm start-session --target i-0374a5ca3623128d3

sudo yum install -y nc
sudo yum install -y postgresql15

ping -c 1 watchlist-api-dev-rds-pg.cge8llp7glxc.us-east-1.rds.amazonaws.com

nslookup watchlist-api-dev-rds-pg.cge8llp7glxc.us-east-1.rds.amazonaws.com

nc -zv watchlist-api-dev-rds-pg.cge8llp7glxc.us-east-1.rds.amazonaws.com 5432

psql \
  -h watchlist-api-dev-rds-pg.cge8llp7glxc.us-east-1.rds.amazonaws.com \
  -U watchlistadmin \
  -d watchlistdb \
  -p 5432


```

```psql
SELECT version();

SELECT current_database(), current_user;

SELECT now();

# write test ----------------------------
CREATE TABLE healthcheck (
  id SERIAL PRIMARY KEY,
  created_at TIMESTAMP DEFAULT now()
);

INSERT INTO healthcheck DEFAULT VALUES;

SELECT * FROM healthcheck;

```

### user_data
Terraform does NOT re-run user_data on existing instances

```sh
terraform apply -replace=aws_instance.private_test

```

## ECS

We shall use a known public container image (like `nginx`, `amazonlinux`, or `busybox`) as a smoke test to validate **IAM roles**, **networking**, **logs**, and **Fargate wiring** before we build our own image.


## CloudFront

```sh
S3_BUCKET=watchlist-api-django-api-static-files
# Upload a test file to S3:
curl -L -o inception.jpg "https://i.ebayimg.com/images/g/LlUAAOSwm8VUwoRL/s-l1200.jpg"
aws s3 cp inception.jpg  s3://${S3_BUCKET}/media/inception.jpg

# Test CloudFront access (should WORK)

CF_DOMAIN_NAME=dyl97f2ar99vk.cloudfront.net
curl -I https://${CF_DOMAIN_NAME}/media/inception.jpg # cloudfront domain name
## HTTP/2 200
## in browser the above link should load the image.
# Refresh once or twice and you should see: `X-Cache: Hit from cloudfront`

curl -I https://${S3_BUCKET}.s3.us-east-1.amazonaws.com/media/inception.jpg
## HTTP/1.1 403 Forbidden
```

cache:
```sh
echo "version 1" > test-static.txt
aws s3 cp test-static.txt s3://${S3_BUCKET}/static/test-static.txt

curl -i https://${CF_DOMAIN_NAME}/static/test-static.txt


echo "version 2" > test-static.txt
aws s3 cp test-static.txt s3://${S3_BUCKET}/static/test-static.txt

curl -i https://${CF_DOMAIN_NAME}/static/test-static.txt

# force refresh:
CF_DIST_ID=E35ALOIVOSSLCE
aws cloudfront create-invalidation \
  --distribution-id $CF_DIST_ID \
  --paths "/static/*"


curl -i https://${CF_DOMAIN_NAME}/static/test-static.txt

```

## ECR

```sh

aws ecr get-login-password \
  | docker login --username AWS --password-stdin $AWS_ACC_ID.dkr.ecr.$AWS_REGION.amazonaws.com

```



```sh

#ssm

aws ec2 describe-route-tables \
  --filters "Name=association.subnet-id,Values=subnet-0ebc77bcab5acd25b"


aws ec2 describe-instances \
  --instance-ids i-0901fe2284a796bed \
  --query "Reservations[0].Instances[0].IamInstanceProfile"


$ aws ssm describe-instance-information
{
    "InstanceInformationList": []
}



aws ec2 describe-security-groups \
  --group-ids sg-0de284008a6781240 \
  --query "SecurityGroups[0].IpPermissionsEgress"

```


## ECS

login
```sh
aws ecr get-login-password --region us-east-1 \
  | docker login \
    --username AWS \
    --password-stdin 451579121839.dkr.ecr.us-east-1.amazonaws.com

```

build the image
```sh
docker build \
  --build-arg DEV=false \
  -t watchlist-api:latest .

# test locally
docker run --rm -p 8000:8000 \
  -e ALLOWED_HOSTS=localhost,127.0.0.1 \
  watchlist-api:latest

curl -i localhost:8000/healthz/

IMG_TAG=v2
docker tag watchlist-api:latest \
  451579121839.dkr.ecr.us-east-1.amazonaws.com/watchlist/api:$IMG_TAG

docker push 451579121839.dkr.ecr.us-east-1.amazonaws.com/watchlist/api:$IMG_TAG


```

```sh
ECR_REPO_URI="451579121839.dkr.ecr.us-east-1.amazonaws.com/watchlist/api"


```


## DB

1. In sg for the rds, for ingress rule 5432 add `security_groups = [aws_security_group.ecs_service.id]`

2. Pass DB env vars to the container
```tf
environment = [
  {
    name  = "ALLOWED_HOSTS"
    value = aws_lb.ecs.dns_name
  },
  ...
]

```


## TF

```sh


```


## ECS exec

```sh
# get task id
aws ecs list-tasks --cluster $CLUSTER_NAME --service-name $SERVICE_NAME

# get container name
aws ecs describe-tasks \
  --cluster $CLUSTER_NAME \
  --tasks $TASK_ID \
  --query 'tasks[0].containers[].name'


aws ecs execute-command \
  --cluster $CLUSTER_NAME \
  --task $TASK_ID \
  --region us-east-1 \
  --container $CONTAINER_NAME \
  --interactive \
  --command "/bin/sh"

# now we can run
python manage.py createsuperuser


# check DB
psql -h $RDS_ENDPOINT -U $DB_USER -d $DB_NAME

\dt

```

```sh
# HOST_=<ALB_DNS_NAME>

ADMIN_TOKEN=$(curl -s -X POST ${HOST_}/api/users/login/ \
  -H "Content-Type: application/json" \
  -d '{
    "email": "kimi@hotmail.com",
    "password": "Berlin97"
  }' | jq -r .access)


curl -X POST "$HOST_/api/movies/" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -F "title=Inception" \
  -F "description=A mind-bending thriller about dreams within dreams." \
  -F "release_year=2010" \
  -F "poster=@inception.jpg"

curl -X POST "$HOST_/api/movies/1/reviews/" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "text": "That docking scene is legendary."
  }'

ACCESS_TOKEN=$(curl -s -X POST ${HOST_}/api/users/login/ \
  -H "Content-Type: application/json" \
  -d '{
    "email": "liv@example.com",
    "password": "London84"
  }' | jq -r .access)

# throw not authorized error
curl -X POST "$HOST_/api/movies/" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -F "title=Inception" \
  -F "description=A mind-bending thriller about dreams within dreams." \
  -F "release_year=2010" \
  -F "poster=@inception.jpg"

curl -X POST "$HOST_/api/movies/1/reviews/" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "text": "dont get the fuss"
  }'


curl "$HOST_/api/movies/1/reviews/" \
  -H "Authorization: Bearer $ADMIN_TOKEN"

curl -X POST "$HOST_/api/movies/1/favorite/" \
  -H "Authorization: Bearer $ADMIN_TOKEN"

curl "$HOST_/api/movies/favorites/" \
  -H "Authorization: Bearer $ADMIN_TOKEN"


curl -X POST "$HOST_/api/users/register/" \
  -H "Content-Type: application/json" \
  -d '{
    "email": "liv@hotmail.com",
    "password": "London84"
  }'

```
