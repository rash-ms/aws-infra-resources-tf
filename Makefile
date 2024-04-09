# Data Infra MakeFile

# <Special Targets>
# Reference: https://www.gnu.org/software/make/manual/html_node/Special-Targets.html
.EXPORT_ALL_VARIABLES:
.ONESHELL:
# </Special Targets>

python_exec=$(shell command -v python3)
# <Recipes>

auth:
		saml2aws login

set_env:
		@echo execute eval $(saml2aws script)

init_backend:
		cd ./infrastructure/tf/src/project-client/tf-s3-backend && terraform init -upgrade

apply_backend:
		cd ./infrastructure/tf/src/project-client/tf-s3-backend && terraform apply

init_remove:
		cd ./infrastructure/tf/src/project-client/tf-s3-backend && rm -dfr ./.terraform

init:
	cd ./infrastructure/tf/src/project-client && terraform init -upgrade

tf_lint_with_write:		
		terraform fmt -recursive -diff=true -write=true .infrastructure/tf/src

tf_lint_without_write:
		terraform fmt -recursive -diff=true -write=false ./infrastructure/tf/src

install_python_deps:
	${python_exec} -m pip install --upgrade pip
	pip install -r ./scripts/temp_setup_scripts/requirements.txt

