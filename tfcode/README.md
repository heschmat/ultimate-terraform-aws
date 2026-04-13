
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

aws sts get-caller-identity

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