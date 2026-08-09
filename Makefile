# Defaults — override with ENGINEER=<id> on the command line
ENGINEER ?= demo
AWS_REGION ?= eu-west-2
AZURE_LOCATION ?= uksouth
RECORDS ?= records

TF_A := terraform/project-a-aws
TF_B_SHARED := terraform/project-b-azure-shared
TF_B := terraform/project-b-azure-engineer
TF_BOOT_AWS := terraform/bootstrap/aws
TF_BOOT_AZURE := terraform/bootstrap/azure

# Keep pipefail so `terraform … | tee` still fails the Make target on plan/apply errors
SHELL := /bin/bash
.SHELLFLAGS := -eu -o pipefail -c

.PHONY: help bootstrap-aws bootstrap-azure \
	init-a plan-a apply-a destroy-a \
	init-b-shared apply-b-shared \
	init-b plan-b apply-b destroy-b \
	fmt validate seed-data stage-app lint

help:
	@echo "SAR sandbox Makefile"
	@echo ""
	@echo "  ENGINEER=$(ENGINEER)  AWS_REGION=$(AWS_REGION)  AZURE_LOCATION=$(AZURE_LOCATION)"
	@echo "  RECORDS=$(RECORDS)   (local plan/apply/output artifacts; gitignored)"
	@echo ""
	@echo "Bootstrap:"
	@echo "  make bootstrap-aws          Create S3 remote state (+ write $(RECORDS)/)"
	@echo "  make bootstrap-azure        Create Azure storage remote state (+ write $(RECORDS)/)"
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
	@echo "  make fmt | validate | lint | seed-data | stage-app"
	@echo "  (Docker is installed/used on the Project A EC2 host, not required locally)"

# ---------------------------------------------------------------------------
# Bootstrap
# ---------------------------------------------------------------------------

bootstrap-aws:
	@mkdir -p $(RECORDS)
	cd $(TF_BOOT_AWS) && terraform init
	cd $(TF_BOOT_AWS) && terraform apply -auto-approve -no-color \
		| tee $(CURDIR)/$(RECORDS)/bootstrap-aws.apply.log
	cd $(TF_BOOT_AWS) && terraform output -no-color \
		| tee $(CURDIR)/$(RECORDS)/bootstrap-aws.outputs.txt
	cd $(TF_BOOT_AWS) && terraform output -json \
		> $(CURDIR)/$(RECORDS)/bootstrap-aws.outputs.json
	@echo "Recorded bootstrap AWS outputs in $(RECORDS)/bootstrap-aws.outputs.*"

bootstrap-azure:
	@mkdir -p $(RECORDS)
	cd $(TF_BOOT_AZURE) && terraform init
	cd $(TF_BOOT_AZURE) && terraform apply -auto-approve -no-color \
		| tee $(CURDIR)/$(RECORDS)/bootstrap-azure.apply.log
	cd $(TF_BOOT_AZURE) && terraform output -no-color \
		| tee $(CURDIR)/$(RECORDS)/bootstrap-azure.outputs.txt
	cd $(TF_BOOT_AZURE) && terraform output -json \
		> $(CURDIR)/$(RECORDS)/bootstrap-azure.outputs.json
	@echo "Recorded bootstrap Azure outputs in $(RECORDS)/bootstrap-azure.outputs.*"

# ---------------------------------------------------------------------------
# Project A — per-engineer workspace
# ---------------------------------------------------------------------------

init-a:
	cd $(TF_A) && terraform init
	cd $(TF_A) && (terraform workspace select $(ENGINEER) 2>/dev/null || terraform workspace new $(ENGINEER))

plan-a: init-a
	@mkdir -p $(RECORDS)
	cd $(TF_A) && terraform plan -no-color \
		-var="engineer_id=$(ENGINEER)" \
		-var="aws_region=$(AWS_REGION)" \
		-out=$(CURDIR)/$(RECORDS)/project-a-$(ENGINEER).tfplan \
		| tee $(CURDIR)/$(RECORDS)/project-a-$(ENGINEER).plan.txt
	@echo "Recorded plan in $(RECORDS)/project-a-$(ENGINEER).plan.txt (+ .tfplan)"

apply-a: init-a
	@mkdir -p $(RECORDS)
	cd $(TF_A) && terraform apply -auto-approve -no-color \
		-var="engineer_id=$(ENGINEER)" \
		-var="aws_region=$(AWS_REGION)" \
		| tee $(CURDIR)/$(RECORDS)/project-a-$(ENGINEER).apply.log
	cd $(TF_A) && terraform output -no-color \
		| tee $(CURDIR)/$(RECORDS)/project-a-$(ENGINEER).outputs.txt
	cd $(TF_A) && terraform output -json \
		> $(CURDIR)/$(RECORDS)/project-a-$(ENGINEER).outputs.json
	@echo "Recorded outputs in $(RECORDS)/project-a-$(ENGINEER).outputs.*"

destroy-a: init-a
	@mkdir -p $(RECORDS)
	cd $(TF_A) && terraform destroy -auto-approve -no-color \
		-var="engineer_id=$(ENGINEER)" \
		-var="aws_region=$(AWS_REGION)" \
		| tee $(CURDIR)/$(RECORDS)/project-a-$(ENGINEER).destroy.log

# ---------------------------------------------------------------------------
# Project B — shared (once) + per-engineer
# ---------------------------------------------------------------------------

init-b-shared:
	cd $(TF_B_SHARED) && terraform init

apply-b-shared: init-b-shared
	@mkdir -p $(RECORDS)
	cd $(TF_B_SHARED) && terraform apply -auto-approve -no-color \
		-var="location=$(AZURE_LOCATION)" \
		| tee $(CURDIR)/$(RECORDS)/project-b-shared.apply.log
	cd $(TF_B_SHARED) && terraform output -no-color \
		| tee $(CURDIR)/$(RECORDS)/project-b-shared.outputs.txt
	cd $(TF_B_SHARED) && terraform output -json \
		> $(CURDIR)/$(RECORDS)/project-b-shared.outputs.json
	@echo "Recorded shared outputs in $(RECORDS)/project-b-shared.outputs.*"

init-b:
	cd $(TF_B) && terraform init
	cd $(TF_B) && (terraform workspace select $(ENGINEER) 2>/dev/null || terraform workspace new $(ENGINEER))

plan-b: init-b
	@test -n "$(METASTORE_ID)" || (echo "Set METASTORE_ID=... ACCESS_CONNECTOR_ID=... ACCESS_CONNECTOR_PRINCIPAL_ID=... from shared outputs"; exit 1)
	@mkdir -p $(RECORDS)
	cd $(TF_B) && terraform plan -no-color \
		-var="engineer_id=$(ENGINEER)" \
		-var="location=$(AZURE_LOCATION)" \
		-var="metastore_id=$(METASTORE_ID)" \
		-var="access_connector_id=$(ACCESS_CONNECTOR_ID)" \
		-var="access_connector_principal_id=$(ACCESS_CONNECTOR_PRINCIPAL_ID)" \
		-out=$(CURDIR)/$(RECORDS)/project-b-$(ENGINEER).tfplan \
		| tee $(CURDIR)/$(RECORDS)/project-b-$(ENGINEER).plan.txt
	@echo "Recorded plan in $(RECORDS)/project-b-$(ENGINEER).plan.txt (+ .tfplan)"

apply-b: init-b
	@test -n "$(METASTORE_ID)" || (echo "Set METASTORE_ID=... ACCESS_CONNECTOR_ID=... ACCESS_CONNECTOR_PRINCIPAL_ID=... from shared outputs"; exit 1)
	@mkdir -p $(RECORDS)
	cd $(TF_B) && terraform apply -auto-approve -no-color \
		-var="engineer_id=$(ENGINEER)" \
		-var="location=$(AZURE_LOCATION)" \
		-var="metastore_id=$(METASTORE_ID)" \
		-var="access_connector_id=$(ACCESS_CONNECTOR_ID)" \
		-var="access_connector_principal_id=$(ACCESS_CONNECTOR_PRINCIPAL_ID)" \
		| tee $(CURDIR)/$(RECORDS)/project-b-$(ENGINEER).apply.log
	cd $(TF_B) && terraform output -no-color \
		| tee $(CURDIR)/$(RECORDS)/project-b-$(ENGINEER).outputs.txt
	cd $(TF_B) && terraform output -json \
		> $(CURDIR)/$(RECORDS)/project-b-$(ENGINEER).outputs.json
	@echo "Recorded outputs in $(RECORDS)/project-b-$(ENGINEER).outputs.*"

destroy-b: init-b
	@test -n "$(METASTORE_ID)" || (echo "Set METASTORE_ID=... ACCESS_CONNECTOR_ID=... ACCESS_CONNECTOR_PRINCIPAL_ID=... from shared outputs"; exit 1)
	@mkdir -p $(RECORDS)
	cd $(TF_B) && terraform destroy -auto-approve -no-color \
		-var="engineer_id=$(ENGINEER)" \
		-var="location=$(AZURE_LOCATION)" \
		-var="metastore_id=$(METASTORE_ID)" \
		-var="access_connector_id=$(ACCESS_CONNECTOR_ID)" \
		-var="access_connector_principal_id=$(ACCESS_CONNECTOR_PRINCIPAL_ID)" \
		| tee $(CURDIR)/$(RECORDS)/project-b-$(ENGINEER).destroy.log

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

# Optional manual stage (Terraform also stages via data.external during plan/apply)
stage-app:
	bash scripts/stage-app-artifact.sh terraform/project-a-aws/.build/app-artifact
