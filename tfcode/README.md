
```sh
Apply complete! Resources: 3 added, 1 changed, 0 destroyed.

Outputs:

postgres_address = "django-ecs-image-default-postgres.ckacvvm9jt6m.us-east-1.rds.amazonaws.com"
postgres_port = 5432
postgres_secret_arn = "arn:aws:secretsmanager:us-east-1:854912240456:secret:rds!db-015165ea-cf4a-47be-930b-ddd057d5e33d-110YeU"
ssm_box_id = "i-07f23ea77fbe22ec4"
vpc_cidr = "vpc-0e91c9568181296b1"

```


Install Session Manager Plugin
```sh
curl "https://s3.amazonaws.com/session-manager-downloads/plugin/latest/ubuntu_64bit/session-manager-plugin.deb" -o "session-manager-plugin.deb"

sudo dpkg -i session-manager-plugin.deb

# verify
ession-manager-plugin
# The Session Manager plugin was installed successfully. Use the AWS CLI to start a session.

```

```sh
aws ssm start-session --target i-07f23ea77fbe22ec4



# inside the shell

whoami
# ssm-user

aws sts get-caller-identity
# {
#     "UserId": "AROA4ODF5RNEOFSAHZIAT:i-08534255e68b3e0b9",
#     "Account": "854912240456",
#     "Arn": "arn:aws:sts::854912240456:assumed-role/ec2-ssm-role/i-08534255e68b3e0b9"
# }


# sudo dnf install -y jq nmap-ncat postgresql17

jq --version
nc -h | head
psql --version

SECRET_ID='arn:aws:secretsmanager:us-east-1:854912240456:secret:rds!db-fc9dd027-533f-4d92-8373-a7977b10c014-zNHgP0'
aws secretsmanager get-secret-value \
  --secret-id $SECRET_ID \
  --query SecretString \
  --output text


nc -zv django-ecs-image-default-postgres.ckacvvm9jt6m.us-east-1.rds.amazonaws.com 5432


SECRET_JSON=$(aws secretsmanager get-secret-value \
  --secret-id ${SECRET_ID} \
  --query SecretString \
  --output text)
echo $SECRET_JSON

export PGHOST="django-ecs-image-default-postgres.ckacvvm9jt6m.us-east-1.rds.amazonaws.com"
export PGPORT=5432
export PGUSER=$(echo "$SECRET_JSON" | jq -r .username)
export PGPASSWORD=$(echo "$SECRET_JSON" | jq -r .password)
export PGDATABASE=app

psql

select current_user, current_database();
select version();
select now();
create table if not exists healthcheck_test(id int);
\dt
```


## ECS

```sh
CLUSTER_NAME="django-ecs-image-default-ecs-cluster"
SERVICE_NAME="django-ecs-image-default-app-service"

aws ecs describe-services --cluster $CLUSTER_NAME --services $SERVICE_NAME
aws ecs list-tasks --cluster $CLUSTER_NAME
aws ecs list-tasks --cluster $CLUSTER_NAME
# {
#     "taskArns": [
#         "arn:aws:ecs:us-east-1:854912240456:task/django-ecs-image-default-ecs-cluster/df40cd613926413ba64d0f5930181a9b"
#     ]
# }

TASK_ID=df40cd613926413ba64d0f5930181a9b
aws ecs describe-tasks --cluster $CLUSTER_NAME --tasks $TASK_ID



NET_INT_ID=$(aws ecs describe-tasks \
  --cluster $CLUSTER_NAME \
  --tasks $TASK_ID \
  --query 'tasks[0].attachments[0].details[?name==`networkInterfaceId`].value' \
  --output text)
echo $NET_INT_ID

# get the task public IP
PUBLIC_IP=$(aws ec2 describe-network-interfaces \
  --network-interface-ids $NET_INT_ID \
  --query 'NetworkInterfaces[0].Association.PublicIp' \
  --output text
)
echo $PUBLIC_IP

# test
curl -i $PUBLIC_IP

curl http://$(aws ec2 describe-network-interfaces \
  --network-interface-ids eni-04b954f79c71e3d99 \
  --query 'NetworkInterfaces[0].Association.PublicIp' \
  --output text)

# step 2 --- (private via ssm_box)
PRIVATE_IP=$(aws ec2 describe-network-interfaces \
  --network-interface-ids $NET_INT_ID \
  --query 'NetworkInterfaces[0].PrivateIpAddress' \
  --output text)

echo $PRIVATE_IP

curl -i http://$PRIVATE_IP
# HTTP/1.1 200 OK
# Server: nginx/1.29.8
# Date: Mon, 13 Apr 2026 23:20:50 GMT
# ...
```

### ECS V3 (alb)
The only future changes will be:
- create ALB in public subnets
- create ALB SG allowing 80 from internet
- ECS SG ingress changes source from EC2 SG → ALB SG
- ECS service gets `load_balancer` block
- keep ECS tasks in private subnets
- keep `assign_public_ip = false`

We now have the standard pattern:
- ALB in public subnets
- ECS tasks in private subnets
- no public IP on tasks
- internet traffic hits the ALB
- ALB forwards to the target group
- target group routes to ECS task private IPs
- ECS SG only allows traffic from the ALB SG

The flow is:
| Laptop → ALB DNS name → ALB listener :80 → target group → ECS task private IP :80 → nginx

```sh
ALB_DNS_NAME=django-ecs-image-default-alb-198176139.us-east-1.elb.amazonaws.com

curl -i $ALB_DNS_NAME
HTTP/1.1 200 OK
Date: Mon, 13 Apr 2026 23:26:07 GMT
```

In the final setup, the ECS Fargate tasks run in private subnets without public IP addresses, so they are not directly reachable from the internet. A public Application Load Balancer is placed in the public subnets and receives HTTP traffic from the internet. The ALB forwards requests to a target group of type `ip`, which routes traffic directly to the private ENIs of the ECS tasks. The ECS task security group only allows inbound traffic from the ALB security group, which keeps the application tier private while still making the service publicly accessible through the load balancer.

## MiSK

```sh
# count (list) vs. for_each (map)
subnets = aws_subnet.private[*].id
subnets = values(aws_subnet.private)[*].id
subnets = [for s in aws_subnet.private : s.id]

# aws_subnet.private["private_1"] ✅
# aws_subnet.private[0] ❌
```
