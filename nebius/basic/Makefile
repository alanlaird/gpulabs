# ============================================================================
# Basic Nebius GPU Nodes
# ============================================================================
# Usage:
#   make create             - L40S nodes (default, ~$3.10/hr total)
#   make create NODE_TYPE=h100  - H100 nodes (~$4.60/hr total)
#   make destroy            - Destroy all nodes (stop billing)
#   make force-destroy      - Force-delete via nebius CLI (when destroy fails)
#   make status             - Show node IPs
#   make ssh1 / make ssh2   - SSH into a node

SHELL := /bin/bash

export PATH := $(HOME)/.nebius/bin:$(PATH)

# ── Node type ─────────────────────────────────────────────────────────────────
NODE_TYPE ?= l40s

ifeq ($(NODE_TYPE),l40s)
  _GPU_PLATFORM := gpu-l40s-a
  _GPU_PRESET   := 1gpu-8vcpu-32gb
  _GPU_LABEL    := L40S Intel 1x
  _GPU_COST     := ~\$$1.55/hr per node (~\$$3.10/hr total)
  TF_NODE_VARS  := -var gpu_platform=$(_GPU_PLATFORM) -var gpu_preset=$(_GPU_PRESET)
else ifeq ($(NODE_TYPE),h100)
  _GPU_PLATFORM := gpu-h100-sxm
  _GPU_PRESET   := 1gpu-16vcpu-200gb
  _GPU_LABEL    := H100 SXM 1x
  _GPU_COST     := ~\$$2.30/hr per node (~\$$4.60/hr total)
  TF_NODE_VARS  := -var gpu_platform=$(_GPU_PLATFORM) -var gpu_preset=$(_GPU_PRESET)
else ifeq ($(NODE_TYPE),h200)
  _GPU_PLATFORM := gpu-h200-sxm
  _GPU_PRESET   := 1gpu-16vcpu-200gb
  _GPU_LABEL    := H200 SXM 1x
  _GPU_COST     := ~\$$3.00/hr per node (~\$$6.00/hr total)
  TF_NODE_VARS  := -var gpu_platform=$(_GPU_PLATFORM) -var gpu_preset=$(_GPU_PRESET)
else
  $(error Unknown NODE_TYPE="$(NODE_TYPE)". Valid values: l40s  h100  h200)
endif

# Paths
TF_DIR   := $(shell pwd)
KEY_FILE := $(TF_DIR)/id_basic
KEY_PUB  := $(TF_DIR)/id_basic.pub

SSH_USER ?= ubuntu

# Token handling
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

.PHONY: help keys init create destroy force-destroy status ssh1 ssh2 clean \
        _check_prereqs _check_tfvars _set_parent_id

## help: Show this help message
help:
	@echo ""
	@printf "$(BOLD)Basic Nebius GPU Nodes$(RESET)\n"
	@echo "======================"
	@echo ""
	@printf "$(CYAN)Workflow:$(RESET)\n"
	@echo "  make create                # L40S nodes (default)"
	@echo "  make create NODE_TYPE=h100 # H100 nodes"
	@echo "  make create NODE_TYPE=h200 # H200 nodes"
	@echo "  make destroy               # tear down (stop billing)"
	@echo ""
	@printf "$(CYAN)Targets:$(RESET)\n"
	@grep -E '^## ' $(MAKEFILE_LIST) | sed 's/## /  /'
	@echo ""
	@printf "$(CYAN)Current config:$(RESET)\n"
	@echo "  NODE_TYPE=$(NODE_TYPE)  →  $(_GPU_LABEL)"
	@echo "  Cost: $(_GPU_COST)"
	@echo ""

## keys: Generate SSH key pair for node access
keys:
	@if [ -f "$(KEY_FILE)" ]; then \
		echo "Key already exists: $(KEY_FILE)"; \
	else \
		echo "Generating SSH key pair..."; \
		ssh-keygen -t ed25519 -f "$(KEY_FILE)" -N "" -C "nebius-basic-key"; \
		echo "Key generated: $(KEY_FILE)"; \
	fi

## init: Initialize Terraform (run once)
init:
	terraform init

## create: Provision two GPU nodes
create: _check_prereqs _check_tfvars keys _set_parent_id
	@echo ""
	@printf "$(BOLD)Provisioning two $(_GPU_LABEL) nodes...$(RESET)\n"
	@printf "  Platform: $(_GPU_PLATFORM) / $(_GPU_PRESET)  ($(_GPU_COST))\n"
	@echo ""
	terraform init -upgrade
	terraform apply -auto-approve $(TF_NODE_VARS)
	@echo ""
	terraform output connection_info
	@echo ""
	@printf "$(GREEN)Nodes ready!$(RESET)\n"

## destroy: Destroy all GPU nodes
destroy:
	@echo ""
	@printf "$(BOLD)$(RED)Destroying all nodes...$(RESET)\n"
	@echo ""
	terraform destroy -auto-approve $(TF_NODE_VARS)
	@echo ""
	@printf "$(GREEN)All nodes destroyed. Billing stopped.$(RESET)\n"

## force-destroy: Force-delete via nebius CLI (use when 'make destroy' fails)
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
	 if [ -z "$$INST1" ] && [ -z "$$INST2" ] && [ -z "$$DISK1" ] && [ -z "$$DISK2" ]; then \
	   echo "Nothing found in terraform state — already clean."; exit 0; \
	 fi; \
	 echo "Deleting instances (parallel)..."; \
	 for ID in $$INST1 $$INST2; do \
	   [ -n "$$ID" ] && nebius compute v1 instance delete --id "$$ID" & \
	 done; \
	 wait; echo ""; \
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
	   nebius_compute_v1_disk.boot_disk_2; do \
	   terraform state rm "$$R" 2>/dev/null || true; \
	 done; \
	 printf "$(GREEN)Force-destroy complete. Billing stopped.$(RESET)\n"

## status: Show node IPs
status:
	@echo ""
	terraform output connection_info 2>/dev/null || echo "No nodes deployed (run 'make create')"
	@echo ""

## ssh1: SSH into GPU node 1
ssh1:
	@IP=$$(terraform output -raw node1_ip 2>/dev/null); \
	 [ -n "$$IP" ] || { echo "No node 1 IP found. Run 'make create' first."; exit 1; }; \
	 ssh -i "$(KEY_FILE)" -o StrictHostKeyChecking=no -o IdentitiesOnly=yes $(SSH_USER)@"$$IP"

## ssh2: SSH into GPU node 2
ssh2:
	@IP=$$(terraform output -raw node2_ip 2>/dev/null); \
	 [ -n "$$IP" ] || { echo "No node 2 IP found. Run 'make create' first."; exit 1; }; \
	 ssh -i "$(KEY_FILE)" -o StrictHostKeyChecking=no -o IdentitiesOnly=yes $(SSH_USER)@"$$IP"

## clean: Remove local Terraform state (does NOT destroy nodes)
clean:
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
