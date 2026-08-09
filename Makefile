# Defaults — override with ENGINEER=<id> on the command line
ENGINEER ?= demo
AWS_REGION ?= eu-west-2
AZURE_LOCATION ?= uksouth

TF_A := terraform/project-a-aws
TF_B_SHARED := terraform/project-b-azure-shared
TF_B := terraform/project-b-azure-engineer
TF_BOOT_AWS := terraform/bootstrap/aws
TF_BOOT_AZURE := terraform/bootstrap/azure

.PHONY: help bootstrap-aws bootstrap-azure \
	init-a plan-a apply-a destroy-a \
	init-b-shared apply-b-shared \
	init-b plan-b apply-b destroy-b \
	fmt validate seed-data package-app lint

help:
	@echo "SAR sandbox Makefile"
	@echo ""
	@echo "  ENGINEER=$(ENGINEER)  AWS_REGION=$(AWS_REGION)  AZURE_LOCATION=$(AZURE_LOCATION)"
	@echo ""
	@echo "Bootstrap:"
	@echo "  make bootstrap-aws          Create S3 + DynamoDB remote state"
	@echo "  make bootstrap-azure        Create Azure storage remote state"
	@echo ""
	@echo "Project A (AWS):"
	@echo "  make init-a ENGINEER=alex"
	@echo "  make plan-a ENGINEER=alex"
	@echo "  make apply-a ENGINEER=alex"
	@echo "  make destroy-a ENGINEER=alex"
	@echo ""
	@echo "Project B (Azure / Databricks):"
	@echo "  make apply-b-shared"
	@echo "  make plan-b ENGINEER=alex"
	@echo "  make apply-b ENGINEER=alex"
	@echo ""
	@echo "Utilities:"
	@echo "  make fmt | validate | lint | seed-data | package-app"

# ---------------------------------------------------------------------------
# Bootstrap
# ---------------------------------------------------------------------------

bootstrap-aws:
	cd $(TF_BOOT_AWS) && terraform init && terraform apply -auto-approve

bootstrap-azure:
	cd $(TF_BOOT_AZURE) && terraform init && terraform apply -auto-approve

# ---------------------------------------------------------------------------
# Project A — per-engineer workspace
# ---------------------------------------------------------------------------

init-a:
	cd $(TF_A) && terraform init
	cd $(TF_A) && terraform workspace select $(ENGINEER) 2>/dev/null || terraform workspace new $(ENGINEER)

plan-a: init-a
	cd $(TF_A) && terraform plan \
		-var="engineer_id=$(ENGINEER)" \
		-var="aws_region=$(AWS_REGION)"

apply-a: init-a package-app
	cd $(TF_A) && terraform apply -auto-approve \
		-var="engineer_id=$(ENGINEER)" \
		-var="aws_region=$(AWS_REGION)"

destroy-a: init-a
	cd $(TF_A) && terraform destroy -auto-approve \
		-var="engineer_id=$(ENGINEER)" \
		-var="aws_region=$(AWS_REGION)"

# ---------------------------------------------------------------------------
# Project B — shared (once) + per-engineer
# ---------------------------------------------------------------------------

init-b-shared:
	cd $(TF_B_SHARED) && terraform init

apply-b-shared: init-b-shared
	cd $(TF_B_SHARED) && terraform apply -auto-approve \
		-var="location=$(AZURE_LOCATION)"

init-b:
	cd $(TF_B) && terraform init
	cd $(TF_B) && terraform workspace select $(ENGINEER) 2>/dev/null || terraform workspace new $(ENGINEER)

plan-b: init-b
	@test -n "$(METASTORE_ID)" || (echo "Set METASTORE_ID=... ACCESS_CONNECTOR_ID=... ACCESS_CONNECTOR_PRINCIPAL_ID=... from shared outputs"; exit 1)
	cd $(TF_B) && terraform plan \
		-var="engineer_id=$(ENGINEER)" \
		-var="location=$(AZURE_LOCATION)" \
		-var="metastore_id=$(METASTORE_ID)" \
		-var="access_connector_id=$(ACCESS_CONNECTOR_ID)" \
		-var="access_connector_principal_id=$(ACCESS_CONNECTOR_PRINCIPAL_ID)"

apply-b: init-b
	@test -n "$(METASTORE_ID)" || (echo "Set METASTORE_ID=... ACCESS_CONNECTOR_ID=... ACCESS_CONNECTOR_PRINCIPAL_ID=... from shared outputs"; exit 1)
	cd $(TF_B) && terraform apply -auto-approve \
		-var="engineer_id=$(ENGINEER)" \
		-var="location=$(AZURE_LOCATION)" \
		-var="metastore_id=$(METASTORE_ID)" \
		-var="access_connector_id=$(ACCESS_CONNECTOR_ID)" \
		-var="access_connector_principal_id=$(ACCESS_CONNECTOR_PRINCIPAL_ID)"

destroy-b: init-b
	@test -n "$(METASTORE_ID)" || (echo "Set METASTORE_ID=... ACCESS_CONNECTOR_ID=... ACCESS_CONNECTOR_PRINCIPAL_ID=... from shared outputs"; exit 1)
	cd $(TF_B) && terraform destroy -auto-approve \
		-var="engineer_id=$(ENGINEER)" \
		-var="location=$(AZURE_LOCATION)" \
		-var="metastore_id=$(METASTORE_ID)" \
		-var="access_connector_id=$(ACCESS_CONNECTOR_ID)" \
		-var="access_connector_principal_id=$(ACCESS_CONNECTOR_PRINCIPAL_ID)"

# ---------------------------------------------------------------------------
# Utilities
# ---------------------------------------------------------------------------

fmt:
	terraform fmt -recursive terraform/

validate:
	@for d in $(TF_BOOT_AWS) $(TF_BOOT_AZURE) $(TF_A) $(TF_B_SHARED) $(TF_B); do \
		echo "==> validating $$d"; \
		(cd $$d && terraform init -backend=false -input=false >/dev/null && terraform validate) || exit 1; \
	done

lint:
	@command -v tflint >/dev/null && tflint --recursive terraform/ || echo "tflint not installed — skip"
	@command -v checkov >/dev/null && checkov -d terraform/ --framework terraform --quiet || echo "checkov not installed — skip"

seed-data:
	python3 seed-data/generator/generate.py --out seed-data/out --seed 42

package-app:
	@mkdir -p /tmp/sar-app-build
	tar -czf /tmp/sar-app-build/app.tar.gz \
		-C app \
		compose django-sar-portal keycloak
	@echo "Packaged app artifact -> /tmp/sar-app-build/app.tar.gz"
