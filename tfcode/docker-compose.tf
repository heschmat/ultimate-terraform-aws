services:
  tf:
    image: hashicorp/terraform:1.15.0-rc1
    user: "1000:1000"
    volumes:
      - ./deploy:/code/deploy
      - ~/.aws:/aws:ro
    working_dir: /code
    environment:
      - AWS_SHARED_CREDENTIALS_FILE=/aws/credentials
      - AWS_CONFIG_FILE=/aws/config
      # - AWS_PROFILE=default
      - TF_VAR_django_secret_key
      - TF_VAR_aws_region
      - TF_VAR_project_name
      - TF_VAR_state_bucket
      - TF_WORKSPACE=${TF_WORKSPACE:-}
