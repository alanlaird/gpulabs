# ============================================================================
# Docker NCCL Multi-Node Test on Nebius GPU Nodes
# ============================================================================
# Usage:
#   make create             - L40S nodes (default, ~$3.10/hr total)
#   make create NODE_TYPE=h100  - H100 SXM nodes (~$4.60/hr total)
#   make test               - Run NCCL all_reduce benchmark
#   make destroy            - Destroy all nodes (stop billing)
#   make status             - Show node IPs
#   make ssh1 / make ssh2   - SSH into a node
#   make provision          - Re-run Ansible without recreating nodes
#
# Test variables:
#   MIN_SIZE=8    MAX_SIZE=128M    NODE_TYPE=l40s|h100

SHELL := /bin/bash

# Ensure nebius CLI is findable even if not yet in shell profile
export PATH := $(HOME)/.nebius/bin:$(PATH)

# ── Node type ─────────────────────────────────────────────────────────────────
# Override with: make create NODE_TYPE=h100
NODE_TYPE ?= l40s

# IB fabric override (each IB NODE_TYPE has a sensible default)
IB_FABRIC ?=

ifeq ($(NODE_TYPE),h100-ib)
  # eu-north1 — H100 8x InfiniBand (fabrics: fabric-2, fabric-3, fabric-4, fabric-6)
  _GPU_PLATFORM := gpu-h100-sxm
  _GPU_PRESET   := 8gpu-128vcpu-1600gb
  _GPU_LABEL    := H100 SXM 8x (InfiniBand, eu-north1)
  _GPU_COST     := ~\$$18.40/hr per node (~\$$36.80/hr total)
  _NRANKS       := 16
  _IB_FABRIC    := $(or $(IB_FABRIC),fabric-2)
  _PROJECT_ID   :=
  _REGION       :=
  TF_NODE_VARS  := -var gpu_platform=$(_GPU_PLATFORM) -var gpu_preset=$(_GPU_PRESET) -var infiniband_fabric=$(_IB_FABRIC)
else ifeq ($(NODE_TYPE),h200-ib)
  # eu-west1 — H200 8x InfiniBand (fabric-5)
  _GPU_PLATFORM := gpu-h200-sxm
  _GPU_PRESET   := 8gpu-128vcpu-1600gb
  _GPU_LABEL    := H200 SXM 8x (InfiniBand, eu-west1)
  _GPU_COST     := ~\$$26.00/hr per node (~\$$52.00/hr total)
  _NRANKS       := 16
  _IB_FABRIC    := $(or $(IB_FABRIC),fabric-5)
  _PROJECT_ID   := project-e01vwk4qpr00em1pjqj6sc
  _REGION       := eu-west1
  TF_NODE_VARS  := -var gpu_platform=$(_GPU_PLATFORM) -var gpu_preset=$(_GPU_PRESET) -var infiniband_fabric=$(_IB_FABRIC) -var parent_id=$(_PROJECT_ID) -var region=$(_REGION)
else ifeq ($(NODE_TYPE),b200-ib)
  # me-west1 — B200 8x InfiniBand (fabric-8a)
  _GPU_PLATFORM := gpu-b200-sxm-a
  _GPU_PRESET   := 8gpu-160vcpu-1792gb
  _GPU_LABEL    := B200 SXM 8x (InfiniBand, me-west1)
  _GPU_COST     := ~\$$TBD/hr per node
  _NRANKS       := 16
  _IB_FABRIC    := $(or $(IB_FABRIC),me-west1-a)
  _PROJECT_ID   := project-i00bh9t3pr00fnna9vw26a
  _REGION       := me-west1
  TF_NODE_VARS  := -var gpu_platform=$(_GPU_PLATFORM) -var gpu_preset=$(_GPU_PRESET) -var infiniband_fabric=$(_IB_FABRIC) -var parent_id=$(_PROJECT_ID) -var region=$(_REGION)
else ifeq ($(NODE_TYPE),h100)
  _GPU_PLATFORM := gpu-h100-sxm
  _GPU_PRESET   := 1gpu-16vcpu-200gb
  _GPU_LABEL    := H100 SXM 1x (TCP networking)
  _GPU_COST     := ~\$$2.30/hr per node (~\$$4.60/hr total)
  _NRANKS       := 2
  _IB_FABRIC    :=
  _PROJECT_ID   :=
  _REGION       :=
  TF_NODE_VARS  := -var gpu_platform=$(_GPU_PLATFORM) -var gpu_preset=$(_GPU_PRESET)
else ifeq ($(NODE_TYPE),l40s)
  _GPU_PLATFORM := gpu-l40s-a
  _GPU_PRESET   := 1gpu-8vcpu-32gb
  _GPU_LABEL    := L40S Intel 1x (TCP networking)
  _GPU_COST     := ~\$$1.55/hr per node (~\$$3.10/hr total)
  _NRANKS       := 2
  _IB_FABRIC    :=
  _PROJECT_ID   :=
  _REGION       :=
  TF_NODE_VARS  := -var gpu_platform=$(_GPU_PLATFORM) -var gpu_preset=$(_GPU_PRESET)
else
  $(error Unknown NODE_TYPE="$(NODE_TYPE)". Valid values: l40s  h100  h100-ib  h200-ib  b200-ib)
endif

# NRANKS: ranks per run (default auto-set by NODE_TYPE, override on CLI)
NRANKS ?= $(_NRANKS)

# Passed to every terraform command that creates/destroys resources

# ── Test config ───────────────────────────────────────────────────────────────
MIN_SIZE ?= 8
MAX_SIZE ?= 128M

# Paths
TF_DIR    := $(shell pwd)
KEY_FILE  := $(TF_DIR)/id_nccl_docker
KEY_PUB   := $(TF_DIR)/id_nccl_docker.pub
INVENTORY := $(TF_DIR)/ansible/inventory.yml
RESULTS   := $(TF_DIR)/results

SSH_USER ?= ubuntu

# Token handling: auto-fetch NEBIUS_IAM_TOKEN if not set
ifndef NEBIUS_IAM_TOKEN
  ifdef NEBIUS_TOKEN
    NEBIUS_IAM_TOKEN := $(NEBIUS_TOKEN)
    export NEBIUS_IAM_TOKEN
  else
    NEBIUS_IAM_TOKEN := $(shell nebius iam get-access-token 2>/dev/null)
    export NEBIUS_IAM_TOKEN
    export NEBIUS_TOKEN := $(NEBIUS_IAM_TOKEN)
    _TOKEN_AUTO_FETCHED := 1
  endif
endif

# Colors
BOLD  := \033[1m
RESET := \033[0m
GREEN := \033[32m
CYAN  := \033[36m
RED   := \033[31m

.DEFAULT_GOAL := help

.PHONY: help keys init create provision test destroy force-destroy status ssh1 ssh2 clean \
        _check_prereqs _check_tfvars _check_inventory _set_parent_id

## help: Show this help message
help:
	@echo ""
	@printf "$(BOLD)Docker NCCL Multi-Node Test — Nebius GPU Nodes$(RESET)\n"
	@echo "================================================"
	@echo ""
	@printf "$(CYAN)Workflow:$(RESET)\n"
	@echo "  make create                    # L40S 1x nodes (default)"
	@echo "  make create NODE_TYPE=h100     # H100 1x nodes (TCP)"
	@echo "  make create NODE_TYPE=h100-ib  # H100 8x IB nodes (eu-north1)"
	@echo "  make create NODE_TYPE=h200-ib  # H200 8x IB nodes (eu-west1)"
	@echo "  make create NODE_TYPE=b200-ib  # B200 8x IB nodes (me-west1)"
	@echo "  make test                  # run NCCL benchmark"
	@echo "  make destroy               # tear down (stop billing)"
	@echo ""
	@printf "$(CYAN)Targets:$(RESET)\n"
	@grep -E '^## ' $(MAKEFILE_LIST) | sed 's/## /  /'
	@echo ""
	@printf "$(CYAN)Current config:$(RESET)\n"
	@echo "  NODE_TYPE=$(NODE_TYPE)  →  $(_GPU_LABEL)"
	@echo "  Cost: $(_GPU_COST)"
	@echo "  MIN_SIZE=$(MIN_SIZE)  MAX_SIZE=$(MAX_SIZE)  NRANKS=$(NRANKS)"
	@echo ""

## keys: Generate SSH key pair for inter-node and local access
keys:
	@if [ -f "$(KEY_FILE)" ]; then \
		echo "Key already exists: $(KEY_FILE)"; \
	else \
		echo "Generating cluster SSH key pair..."; \
		ssh-keygen -t ed25519 -f "$(KEY_FILE)" -N "" -C "nccl-docker-cluster-key"; \
		echo "Key generated: $(KEY_FILE)"; \
	fi

## init: Initialize Terraform (run once)
init:
	@echo "Initializing Terraform..."
	terraform init

## create: Provision GPU nodes, install Docker, pull NCCL image
create: _check_prereqs _check_tfvars keys _set_parent_id
	@echo ""
	@printf "$(BOLD)Provisioning two $(_GPU_LABEL) nodes...$(RESET)\n"
	@printf "  Platform: $(_GPU_PLATFORM) / $(_GPU_PRESET)  ($(_GPU_COST))\n"
	@echo ""
	terraform init -upgrade
	terraform apply -auto-approve $(TF_NODE_VARS)
	@echo ""
	@printf "$(GREEN)Nodes ready! Run 'make test' to benchmark.$(RESET)\n"

## provision: Re-run Ansible setup without recreating nodes
provision: _check_inventory
	@echo "Re-running Docker setup playbook..."
	@IP1=$$(grep -A3 "gpu1:" $(INVENTORY) | grep ansible_host | awk '{print $$2}'); \
	 IP2=$$(grep -A3 "gpu2:" $(INVENTORY) | grep ansible_host | awk '{print $$2}'); \
	 ./scripts/provision.sh "$$IP1" "$$IP2" "$(SSH_USER)" "$(KEY_FILE)"

## test: Run NCCL benchmark — per-node (Docker) + inter-node (MPI)
test: _check_inventory
	@mkdir -p $(RESULTS)
	@./scripts/run-docker-test.sh "$(MIN_SIZE)" "$(MAX_SIZE)" "$(NRANKS)"

## destroy: Destroy all GPU nodes and Nebius resources
destroy:
	@echo ""
	@printf "$(BOLD)$(RED)Destroying all nodes...$(RESET)\n"
	@echo ""
	terraform destroy -auto-approve $(TF_NODE_VARS)
	@echo ""
	@printf "$(GREEN)All nodes destroyed. Billing stopped.$(RESET)\n"

## force-destroy: Force-delete via nebius CLI (use when 'make destroy' fails — e.g. nodes stuck in STARTING)
force-destroy:
	@echo ""
	@printf "$(BOLD)$(RED)Force-destroying all nodes via nebius CLI...$(RESET)\n"
	@echo ""
	@JSON=$$(terraform show -json 2>/dev/null); \
	 get_id() { echo "$$JSON" | jq -r ".values.root_module.resources[]? | select(.address==\"$$1\") | .values.id // empty" 2>/dev/null; }; \
	 INST1=$$(get_id nebius_compute_v1_instance.gpu_node_1); \
	 INST2=$$(get_id nebius_compute_v1_instance.gpu_node_2); \
	 DISK1=$$(get_id nebius_compute_v1_disk.boot_disk_1); \
	 DISK2=$$(get_id nebius_compute_v1_disk.boot_disk_2); \
	 CLUSTER=$$(get_id 'nebius_compute_v1_gpu_cluster.ib_cluster[0]'); \
	 if [ -z "$$INST1" ] && [ -z "$$INST2" ] && [ -z "$$DISK1" ] && [ -z "$$DISK2" ]; then \
	   echo "Nothing found in terraform state — already clean."; exit 0; \
	 fi; \
	 echo "Deleting instances (parallel)..."; \
	 for ID in $$INST1 $$INST2; do \
	   [ -n "$$ID" ] && nebius compute v1 instance delete --id "$$ID" & \
	 done; \
	 wait; echo ""; \
	 if [ -n "$$CLUSTER" ]; then \
	   echo "Deleting GPU cluster..."; \
	   nebius compute v1 gpu-cluster delete --id "$$CLUSTER"; \
	   echo ""; \
	 fi; \
	 echo "Deleting boot disks (parallel)..."; \
	 for ID in $$DISK1 $$DISK2; do \
	   [ -n "$$ID" ] && nebius compute v1 disk delete --id "$$ID" & \
	 done; \
	 wait; echo ""; \
	 echo "Removing from terraform state..."; \
	 for R in \
	   nebius_compute_v1_instance.gpu_node_1 \
	   nebius_compute_v1_instance.gpu_node_2 \
	   nebius_compute_v1_disk.boot_disk_1 \
	   nebius_compute_v1_disk.boot_disk_2 \
	   'nebius_compute_v1_gpu_cluster.ib_cluster[0]' \
	   null_resource.docker_setup; do \
	   terraform state rm "$$R" 2>/dev/null || true; \
	 done; \
	 printf "$(GREEN)Force-destroy complete. Billing stopped.$(RESET)\n"

## status: Show node IPs and SSH connection commands
status:
	@echo ""
	terraform output connection_info 2>/dev/null || echo "No nodes deployed (run 'make create')"
	@echo ""

## ssh1: SSH into GPU node 1
ssh1: _check_inventory
	@IP=$$(grep -A3 "gpu1:" $(INVENTORY) | grep ansible_host | awk '{print $$2}'); \
	 ssh -i "$(KEY_FILE)" -o StrictHostKeyChecking=no -o IdentitiesOnly=yes $(SSH_USER)@"$$IP"

## ssh2: SSH into GPU node 2
ssh2: _check_inventory
	@IP=$$(grep -A3 "gpu2:" $(INVENTORY) | grep ansible_host | awk '{print $$2}'); \
	 ssh -i "$(KEY_FILE)" -o StrictHostKeyChecking=no -o IdentitiesOnly=yes $(SSH_USER)@"$$IP"

## clean: Remove local state files (does NOT destroy nodes)
clean:
	rm -f $(INVENTORY)
	rm -rf .terraform .terraform.lock.hcl terraform.tfstate terraform.tfstate.backup
	@echo "Cleaned local state files."

# ── Internal helpers ──────────────────────────────────────────────────────────

_set_parent_id:
	@CURRENT=$$(grep '^parent_id' terraform.tfvars | sed 's/.*= *"\(.*\)"/\1/'); \
	if [ -n "$$CURRENT" ]; then \
		echo "  parent_id: $$CURRENT (already set)"; \
	else \
		printf "  parent_id is empty — fetching from nebius CLI...\n"; \
		TENANT=$$(nebius iam tenant list --format json 2>/dev/null | jq -r '.items[0].metadata.id'); \
		if [ -z "$$TENANT" ] || [ "$$TENANT" = "null" ]; then \
			printf "$(RED)ERROR: Could not get tenant ID from nebius CLI$(RESET)\n"; \
			exit 1; \
		fi; \
		REGION=$$(grep '^region' terraform.tfvars 2>/dev/null | sed 's/.*= *"\(.*\)"/\1/'); \
		REGION=$${REGION:-eu-north1}; \
		PROJECTS=$$(nebius iam project list --parent-id "$$TENANT" --format json 2>/dev/null); \
		MATCHING=$$(echo "$$PROJECTS" | jq --arg r "$$REGION" '[.items[] | select(.spec.region == $$r)]'); \
		COUNT=$$(echo "$$MATCHING" | jq 'length'); \
		if [ "$$COUNT" -eq 0 ]; then \
			printf "$(RED)ERROR: No projects found for region $$REGION$(RESET)\n"; \
			exit 1; \
		fi; \
		PROJECT_ID=$$(echo "$$MATCHING" | jq -r '.[0].metadata.id'); \
		sed -i.bak "s|^parent_id = \".*\"|parent_id = \"$$PROJECT_ID\"|" terraform.tfvars; \
		rm -f terraform.tfvars.bak; \
		printf "  $(GREEN)Updated parent_id: $$PROJECT_ID$(RESET)\n"; \
	fi

_check_prereqs:
	@echo "Checking prerequisites..."
	@command -v terraform >/dev/null 2>&1 || { echo "ERROR: terraform not found"; exit 1; }
	@command -v ansible-playbook >/dev/null 2>&1 || { \
		echo "ERROR: ansible-playbook not found (brew install ansible)"; exit 1; }
	@command -v nebius >/dev/null 2>&1 || { \
		printf "$(RED)ERROR: nebius CLI not found$(RESET)\n"; \
		echo "  Install: curl -sSL https://storage.eu-north1.nebius.cloud/cli/install.sh | bash"; \
		exit 1; \
	}
ifdef _TOKEN_AUTO_FETCHED
	@printf "$(CYAN)Note:$(RESET) NEBIUS_IAM_TOKEN auto-fetched via nebius CLI.\n"
endif
	@[ -n "$$NEBIUS_IAM_TOKEN" ] || { \
		printf "$(RED)ERROR: NEBIUS_IAM_TOKEN is empty$(RESET)\n"; \
		echo "  Try: nebius iam get-access-token"; \
		exit 1; \
	}
	@echo "  All prerequisites met."

_check_tfvars:
	@[ -f terraform.tfvars ] || { \
		echo "ERROR: terraform.tfvars not found."; \
		echo "  Copy terraform.tfvars.example to terraform.tfvars and edit."; \
		exit 1; \
	}

_check_inventory:
	@[ -f "$(INVENTORY)" ] || { \
		echo "ERROR: No inventory found — nodes not yet provisioned."; \
		echo "  Run 'make create' first."; \
		exit 1; \
	}
