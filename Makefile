TF=docker compose run --rm tf

SETUP_DIR=setup
DEPLOY_DIR=deploy

.PHONY: init fmt validate plan apply destroy setup deploy help

help:
	@echo "Terraform commands:"
	@echo ""
	@echo "  make setup-init        Initialize setup Terraform"
	@echo "  make setup-fmt         Format setup Terraform"
	@echo "  make setup-validate    Validate setup Terraform"
	@echo "  make setup-plan        Plan setup Terraform"
	@echo "  make setup-apply       Apply setup Terraform"
	@echo ""
	@echo "  make deploy-init       Initialize deploy Terraform"
	@echo "  make deploy-plan       Plan deploy Terraform"
	@echo "  make deploy-apply      Apply deploy Terraform"
	@echo ""
	@echo "  make destroy-setup     Destroy setup infrastructure"
	@echo "  make destroy-deploy    Destroy deploy infrastructure"

# -----------------
# SETUP
# -----------------
setup-init:
	$(TF) -chdir=$(SETUP_DIR) init

setup-fmt:
	$(TF) -chdir=$(SETUP_DIR) fmt -recursive

setup-validate:
	$(TF) -chdir=$(SETUP_DIR) validate

setup-plan:
	$(TF) -chdir=$(SETUP_DIR) plan

setup-apply:
	$(TF) -chdir=$(SETUP_DIR) apply

destroy-setup:
	$(TF) -chdir=$(SETUP_DIR) destroy

# -----------------
# DEPLOY
# -----------------
deploy-init:
	$(TF) -chdir=$(DEPLOY_DIR) init

deploy-fmt:
	$(TF) -chdir=$(DEPLOY_DIR) fmt -recursive

deploy-validate:
	$(TF) -chdir=$(DEPLOY_DIR) validate

deploy-plan:
	$(TF) -chdir=$(DEPLOY_DIR) plan

deploy-apply:
	$(TF) -chdir=$(DEPLOY_DIR) apply

destroy-deploy:
	$(TF) -chdir=$(DEPLOY_DIR) destroy
