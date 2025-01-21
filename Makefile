# Data Infra MakeFile

# <Special Targets>
# Reference: https://www.gnu.org/software/make/manual/html_node/Special-Targets.html
.EXPORT_ALL_VARIABLES:
.ONESHELL:
# </Special Targets>

python_exec=$(shell command -v python3)

# <Recipes>

TERRAFORM_DIR = ../aws-resources-deployment

auth:
		saml2aws login

set_env:
		@echo execute eval $(saml2aws script)

init_backend:
		cd ${TERRAFORM_DIR}/s3-backend && terraform init -upgrade

plan_backend:
		cd $(TERRAFORM_DIR)/s3-backend && terraform plan

apply_backend:
		cd ${TERRAFORM_DIR}/s3-backend && terraform apply


init:
		cd ${TERRAFORM_DIR} && terraform init -upgrade

plan:
		cd $(TERRAFORM_DIR) && terraform plan

apply:
		cd ${TERRAFORM_DIR} && terraform apply -auto-approve

init_remove:
		cd ${TERRAFORM_DIR} && rm -dfr ./.terraform

destroy:
		cd $(TERRAFORM_DIR) && terraform destroy -auto-approve

init_remove:
		cd $(TERRAFORM_DIR) && rm -dfr ./.terraform

destroy:
		cd $(TERRAFORM_DIR) && terraform destroy

# Linting for Terraform
tf_lint_with_write:		
		terraform fmt -recursive -diff=true -write=true ./aws-resources-infra

tf_lint_without_write:
		terraform fmt -recursive -diff=true -write=false ./aws-resources-infra

# Python dependencies installation
install_python_deps:
	${python_exec} -m pip install --upgrade pip
	pip install -r ./scripts/temp_setup_scripts/requirements.txt
