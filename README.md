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

## ECS

We shall use a known public container image (like `nginx`, `amazonlinux`, or `busybox`) as a smoke test to validate **IAM roles**, **networking**, **logs**, and **Fargate wiring** before we build our own image.


## ECR

```sh

aws ecr get-login-password \
  | docker login --username AWS --password-stdin $AWS_ACC_ID.dkr.ecr.$AWS_REGION.amazonaws.com

```

