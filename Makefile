# Ansible Node Deployment Workflow - Makefile
# ===========================================

# Configuration
PYTHON_VERSION := $(shell python3 --version 2>/dev/null | cut -d' ' -f2 | cut -d'.' -f1,2 || echo "3")
PYTHON_CMD := $(shell which python3 2>/dev/null || which python 2>/dev/null || echo "python3")
VENV_DIR := venv
PYTHON := $(VENV_DIR)/bin/python
PIP := $(VENV_DIR)/bin/pip
ANSIBLE_PLAYBOOK := $(VENV_DIR)/bin/ansible-playbook
ANSIBLE := $(VENV_DIR)/bin/ansible
SEDGE_BINARY := ./sedge
LOCAL_DEPLOYMENT_DIR := ./local-deployment

# Default parameters for playbook execution
NETWORK ?= sepolia
CL_CLIENT ?= lodestar
SYNC_MODE ?= fast
NON_VALIDATOR_MODE ?= true
UPDATE ?= false
VERBOSITY ?= -v

# Colors for output
BLUE := \033[0;34m
GREEN := \033[0;32m
YELLOW := \033[1;33m
RED := \033[0;31m
NC := \033[0m # No Color

.PHONY: help venv install clean test run run-dev run-prod check-env lint validate clean-artifacts info activate local-deploy local-dev local-mainnet local-status local-stop local-clean local-logs check-docker local-validate local-archive vagrant-up vagrant-provision vagrant-deploy vagrant-halt vagrant-destroy vagrant-ssh proxmox-deploy

# Default target
.DEFAULT_GOAL := help

help: ## Show this help message
	@echo -e "$(BLUE)Ansible Node Deployment Workflow$(NC)"
	@echo -e "$(BLUE)==================================$(NC)"
	@echo ""
	@echo "Available targets:"
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  $(GREEN)%-18s$(NC) %s\n", $$1, $$2}' $(MAKEFILE_LIST)
	@echo ""
	@echo "Environment variables:"
	@echo -e "  $(YELLOW)NETWORK$(NC)              Network to deploy on (default: $(NETWORK))"
	@echo -e "  $(YELLOW)CL_CLIENT$(NC)            Consensus layer client (default: $(CL_CLIENT))"
	@echo -e "  $(YELLOW)SYNC_MODE$(NC)            Sync mode: fast, full, archive (default: $(SYNC_MODE))"
	@echo -e "  $(YELLOW)NON_VALIDATOR_MODE$(NC)   Non-validator mode (default: $(NON_VALIDATOR_MODE))"
	@echo -e "  $(YELLOW)UPDATE$(NC)               Update sedge binary: true/false (default: $(UPDATE))"
	@echo -e "  $(YELLOW)VERBOSITY$(NC)            Ansible verbosity (default: $(VERBOSITY))"
	@echo ""
	@echo "Remote deployment examples:"
	@echo "  make run NETWORK=mainnet CL_CLIENT=prysm"
	@echo "  make run-dev"
	@echo "  make run-prod VERBOSITY=-vvv"
	@echo ""
	@echo "Local deployment examples (using Sedge):"
	@echo "  make local-dev                           # Deploy local testnet (Sepolia + Lodestar)"
	@echo "  make local-dev UPDATE=true               # Deploy local testnet (with sedge update)"
	@echo "  make local-deploy NETWORK=holesky        # Deploy specific network"
	@echo "  make local-deploy NETWORK=holesky UPDATE=true  # Deploy with sedge update"
	@echo "  make local-mainnet                       # Deploy mainnet node"
	@echo "  make local-mainnet UPDATE=true           # Deploy mainnet node (with sedge update)"
	@echo "  make local-archive NETWORK=sepolia       # Deploy archive node"
	@echo "  make local-deploy CL_CLIENT=lighthouse   # Use different consensus client"
	@echo "  make local-deploy SYNC_MODE=full         # Use full sync mode"
	@echo "  make local-status                        # Check node status"
	@echo "  make local-logs                          # View node logs"
	@echo "  make local-stop                          # Stop all nodes"
	@echo "  make local-clean                         # Clean up containers"

$(VENV_DIR): ## Create Python virtual environment
	@echo -e "$(BLUE)Creating Python virtual environment...$(NC)"
	@echo "Using Python: $(PYTHON_CMD) (version $(PYTHON_VERSION))"
	$(PYTHON_CMD) -m venv $(VENV_DIR)
	@echo -e "$(GREEN)Virtual environment created at $(VENV_DIR)$(NC)"

venv: $(VENV_DIR) ## Create virtual environment (alias)

install: $(VENV_DIR) ## Install Python dependencies
	@echo -e "$(BLUE)Installing Python dependencies...$(NC)"
	$(PIP) install --upgrade pip wheel setuptools
	$(PIP) install -r requirements.txt
	@echo -e "$(GREEN)Dependencies installed successfully$(NC)"

upgrade: $(VENV_DIR) ## Upgrade all Python packages
	@echo -e "$(BLUE)Upgrading Python packages...$(NC)"
	$(PIP) install --upgrade pip wheel setuptools
	$(PIP) install --upgrade -r requirements.txt
	@echo -e "$(GREEN)Packages upgraded successfully$(NC)"

check-env: $(VENV_DIR) ## Check required environment variables
	@echo -e "$(BLUE)Checking environment configuration...$(NC)"
	@if [ -z "$$GITHUB_TOKEN" ]; then \
		echo -e "$(RED)Error: GITHUB_TOKEN environment variable is not set$(NC)"; \
		echo "Please set it with: export GITHUB_TOKEN='your_token_here'"; \
		exit 1; \
	fi
	@if [ -z "$$GITHUB_ACTOR" ]; then \
		echo -e "$(YELLOW)Warning: GITHUB_ACTOR not set, will use current user$(NC)"; \
	fi
	@echo -e "$(GREEN)Environment configuration looks good$(NC)"

validate: install ## Validate Ansible playbook syntax
	@echo -e "$(BLUE)Validating Ansible playbook syntax...$(NC)"
	$(ANSIBLE_PLAYBOOK) playbook.yml --syntax-check
	@echo -e "$(GREEN)Playbook syntax is valid$(NC)"

lint: install ## Run ansible-lint on playbook
	@echo -e "$(BLUE)Running Ansible lint...$(NC)"
	@if $(VENV_DIR)/bin/ansible-lint --version >/dev/null 2>&1; then \
		$(VENV_DIR)/bin/ansible-lint playbook.yml; \
	else \
		echo -e "$(YELLOW)ansible-lint not installed, install with: pip install ansible-lint$(NC)"; \
		echo "Skipping lint check..."; \
	fi

test: validate ## Run basic tests (syntax check)
	@echo -e "$(BLUE)Running basic tests...$(NC)"
	@echo -e "$(GREEN)✅ All tests passed$(NC)"

run: install check-env ## Run the complete workflow
	@echo -e "$(BLUE)Running Ansible workflow...$(NC)"
	@echo "Parameters: NETWORK=$(NETWORK), CL_CLIENT=$(CL_CLIENT), CONFIG=$(CONFIG)"
	$(ANSIBLE_PLAYBOOK) playbook.yml \
		-e "network=$(NETWORK)" \
		-e "cl_client=$(CL_CLIENT)" \
		-e "config=$(CONFIG)" \
		-e "non_validator_mode=$(NON_VALIDATOR_MODE)" \
		$(VERBOSITY)

run-dev: install check-env ## Run with development settings
	@echo -e "$(BLUE)Running workflow in development mode...$(NC)"
	$(ANSIBLE_PLAYBOOK) playbook.yml \
		-e "network=sepolia" \
		-e "cl_client=lighthouse" \
		-e "config=fastSync.json" \
		-e 'additional_options={"timeout":"12", "default_dockerfile_build_type":"debug"}' \
		$(VERBOSITY)

run-prod: install check-env ## Run with production settings
	@echo -e "$(BLUE)Running workflow in production mode...$(NC)"
	@echo -e "$(YELLOW)Using production settings - this may take longer$(NC)"
	$(ANSIBLE_PLAYBOOK) playbook.yml \
		-e "network=mainnet" \
		-e "cl_client=prysm" \
		-e "config=fullSync.json" \
		-e "non_validator_mode=false" \
		-e 'additional_options={"timeout":"72", "custom_machine_type":"n1-standard-8"}' \
		$(VERBOSITY)

run-docker-only: install check-env ## Run only Docker image creation
	@echo -e "$(BLUE)Running Docker image creation only...$(NC)"
	$(ANSIBLE_PLAYBOOK) playbook.yml --tags docker_image $(VERBOSITY)

run-node-only: install check-env ## Run only node creation (requires existing base_tag)
	@echo -e "$(BLUE)Running node creation only...$(NC)"
	@if [ -z "$(BASE_TAG)" ]; then \
		echo -e "$(RED)Error: BASE_TAG variable is required for node-only execution$(NC)"; \
		echo "Usage: make run-node-only BASE_TAG=your_base_tag"; \
		exit 1; \
	fi
	$(ANSIBLE_PLAYBOOK) playbook.yml --tags node_creation \
		-e "base_tag=$(BASE_TAG)" \
		$(VERBOSITY)

info: install ## Show Ansible and system information
	@echo -e "$(BLUE)System and Ansible Information$(NC)"
	@echo "=============================="
	@echo "Python version: $$($(PYTHON) --version)"
	@echo "Pip version: $$($(PIP) --version)"
	@echo "Ansible version: $$($(ANSIBLE) --version | head -n1)"
	@echo "Virtual environment: $(VENV_DIR)"
	@echo "Current directory: $$(pwd)"
	@echo ""
	@echo -e "$(BLUE)Environment Variables$(NC)"
	@echo "===================="
	@echo "GITHUB_ACTOR: $${GITHUB_ACTOR:-<not set>}"
	@echo "GITHUB_REPO_OWNER: $${GITHUB_REPO_OWNER:-<not set>}"
	@echo "GITHUB_REPO_NAME: $${GITHUB_REPO_NAME:-<not set>}"
	@echo "GITHUB_TOKEN: $${GITHUB_TOKEN:+<set>}$${GITHUB_TOKEN:-<not set>}"

inventory: install ## Show inventory information
	@echo -e "$(BLUE)Ansible Inventory Information$(NC)"
	@echo "============================="
	$(ANSIBLE) localhost -i inventory.ini -m setup -a "filter=ansible_python*"

clean-artifacts: ## Clean up downloaded artifacts and temporary files
	@echo -e "$(BLUE)Cleaning up artifacts and temporary files...$(NC)"
	@rm -rf /tmp/ansible-workflow-*
	@rm -rf artifacts/
	@echo -e "$(GREEN)Artifacts cleaned up$(NC)"

clean-venv: ## Remove Python virtual environment
	@echo -e "$(BLUE)Removing Python virtual environment...$(NC)"
	@rm -rf $(VENV_DIR)
	@echo -e "$(GREEN)Virtual environment removed$(NC)"

clean: clean-artifacts clean-venv ## Clean everything (artifacts + virtual environment)
	@echo -e "$(GREEN)Everything cleaned up$(NC)"

dev-deps: install ## Install development dependencies
	@echo -e "$(BLUE)Installing development dependencies...$(NC)"
	$(PIP) install ansible-lint pytest pytest-ansible black isort mypy
	@echo -e "$(GREEN)Development dependencies installed$(NC)"

shell: install ## Activate virtual environment shell
	@echo -e "$(BLUE)Activating virtual environment...$(NC)"
	@echo -e "$(YELLOW)To activate manually: source $(VENV_DIR)/bin/activate$(NC)"
	@exec bash --init-file <(echo "source $(VENV_DIR)/bin/activate; echo 'Virtual environment activated'")

activate: install ## Show how to activate virtual environment
	@echo -e "$(BLUE)Virtual Environment Activation Help$(NC)"
	@echo -e "$(BLUE)===================================$(NC)"
	@echo ""
	@echo -e "$(YELLOW)To activate in your current shell:$(NC)"
	@echo -e "  $(GREEN)source ./activate-venv.sh$(NC)"
	@echo ""
	@echo -e "$(YELLOW)Alternative methods:$(NC)"
	@echo -e "  $(GREEN)source venv/bin/activate$(NC)"
	@echo -e "  $(GREEN). ./activate-venv.sh$(NC)"
	@echo ""
	@echo -e "$(YELLOW)⚠️  Don't do this (won't work):$(NC)"
	@echo -e "  $(RED)./activate-venv.sh$(NC)  ← Executed, not sourced"
	@echo ""
	@echo -e "$(YELLOW)After activation, verify with:$(NC)"
	@echo -e "  $(BLUE)which python$(NC)     → Should show venv/bin/python"
	@echo -e "  $(BLUE)which ansible$(NC)    → Should show venv/bin/ansible"
	@echo ""
	@echo -e "$(YELLOW)Or use Make commands (no manual activation needed):$(NC)"
	@echo -e "  $(GREEN)make run$(NC), $(GREEN)make run-dev$(NC), $(GREEN)make info$(NC), etc."

# Advanced targets
freeze: install ## Generate current package versions
	@echo -e "$(BLUE)Current package versions:$(NC)"
	$(PIP) freeze

outdated: install ## Show outdated packages
	@echo -e "$(BLUE)Outdated packages:$(NC)"
	$(PIP) list --outdated

init: ## Initialize new environment (create venv, install deps, validate)
	@echo -e "$(BLUE)Initializing new environment...$(NC)"
	@$(MAKE) venv
	@$(MAKE) install
	@$(MAKE) validate
	@echo -e "$(GREEN)Environment initialized successfully!$(NC)"
	@echo -e "$(YELLOW)Don't forget to set your environment variables (see env.example)$(NC)"

# Local deployment targets
local-deploy: install check-docker ## Deploy local Ethereum nodes using Sedge
	@echo -e "$(BLUE)Deploying local Ethereum node using Sedge...$(NC)"
	@echo "Parameters: NETWORK=$(NETWORK), CL_CLIENT=$(CL_CLIENT), SYNC_MODE=$(SYNC_MODE), UPDATE=$(UPDATE)"
	$(ANSIBLE_PLAYBOOK) playbook-local-sedge.yml \
		-e "network=$(NETWORK)" \
		-e "cl_client=$(CL_CLIENT)" \
		-e "sync_mode=$(SYNC_MODE)" \
		-e "non_validator_mode=$(NON_VALIDATOR_MODE)" \
		$(if $(filter-out true,$(UPDATE)),--skip-tags sedge_update,) \
		$(VERBOSITY)

local-dev: install check-docker ## Deploy local nodes with development settings
	@echo -e "$(BLUE)Deploying local development environment using Sedge...$(NC)"
	@echo "Parameters: UPDATE=$(UPDATE)"
	$(ANSIBLE_PLAYBOOK) playbook-local-sedge.yml \
		-e "network=sepolia" \
		-e "cl_client=lodestar" \
		-e "sync_mode=fast" \
		$(if $(filter-out true,$(UPDATE)),--skip-tags sedge_update,) \
		$(VERBOSITY)

local-mainnet: install check-docker ## Deploy local nodes for mainnet
	@echo -e "$(BLUE)Deploying local mainnet environment using Sedge...$(NC)"
	@echo -e "$(YELLOW)Warning: This will sync mainnet - requires significant disk space and time$(NC)"
	@echo "Parameters: UPDATE=$(UPDATE)"
	$(ANSIBLE_PLAYBOOK) playbook-local-sedge.yml \
		-e "network=mainnet" \
		-e "cl_client=lodestar" \
		-e "sync_mode=full" \
		-e "non_validator_mode=false" \
		$(if $(filter-out true,$(UPDATE)),--skip-tags sedge_update,) \
		$(VERBOSITY)

local-status: ## Check status of local deployment
	@echo -e "$(BLUE)Checking local deployment status...$(NC)"
	@docker ps --filter "name=sedge" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" || echo "No Sedge containers running"

local-stop: install ## Stop local Ethereum nodes
	@echo -e "$(BLUE)Stopping local Ethereum nodes using Sedge...$(NC)"
	@if [ -f "$(SEDGE_BINARY)" ] && [ -d "$(LOCAL_DEPLOYMENT_DIR)" ]; then \
		$(SEDGE_BINARY) down -p $(LOCAL_DEPLOYMENT_DIR); \
	else \
		echo -e "$(YELLOW)No Sedge deployment found$(NC)"; \
	fi

local-clean: ## Clean up local deployment (containers, networks, volumes)
	@echo -e "$(BLUE)Cleaning up local deployment...$(NC)"
	@$(MAKE) local-stop
	@docker container rm $$(docker ps -aq --filter "name=sedge") 2>/dev/null || echo "No Sedge containers to remove"
	@docker network rm sedge_default 2>/dev/null || echo "No Sedge network to remove"
	@echo -e "$(YELLOW)Data directories preserved in $(LOCAL_DEPLOYMENT_DIR)$(NC)"
	@echo -e "$(YELLOW)To remove data: rm -rf $(LOCAL_DEPLOYMENT_DIR)$(NC)"

local-logs: ## Show logs from local nodes
	@echo -e "$(BLUE)Local node logs (press Ctrl+C to exit):$(NC)"
	@if [ -f "$(SEDGE_BINARY)" ] && [ -d "$(LOCAL_DEPLOYMENT_DIR)" ]; then \
		$(SEDGE_BINARY) logs -p $(LOCAL_DEPLOYMENT_DIR); \
	else \
		echo -e "$(YELLOW)No Sedge deployment found$(NC)"; \
	fi

check-docker: ## Check Docker installation and daemon
	@echo -e "$(BLUE)Checking Docker...$(NC)"
	@if ! command -v docker &> /dev/null; then \
		echo -e "$(RED)Error: Docker is not installed$(NC)"; \
		echo "Please install Docker: https://docs.docker.com/get-docker/"; \
		exit 1; \
	fi
	@if ! docker info &> /dev/null; then \
		echo -e "$(RED)Error: Docker daemon is not running$(NC)"; \
		echo "Please start Docker daemon"; \
		exit 1; \
	fi
	@echo -e "$(GREEN)Docker is ready$(NC)"

local-validate: install ## Validate local deployment playbook
	@echo -e "$(BLUE)Validating local deployment playbook...$(NC)"
	$(ANSIBLE_PLAYBOOK) playbook-local-sedge.yml --syntax-check
	@echo -e "$(GREEN)Local playbook syntax is valid$(NC)"



local-archive: install check-docker ## Deploy local archive node
	@echo -e "$(BLUE)Deploying local archive node using Sedge...$(NC)"
	@echo -e "$(YELLOW)Warning: Archive mode requires significant disk space$(NC)"
	@echo "Parameters: NETWORK=$(NETWORK), CL_CLIENT=$(CL_CLIENT), UPDATE=$(UPDATE)"
	$(ANSIBLE_PLAYBOOK) playbook-local-sedge.yml \
		-e "network=$(NETWORK)" \
		-e "cl_client=$(CL_CLIENT)" \
		-e "sync_mode=archive" \
		-e "non_validator_mode=true" \
		$(if $(filter-out true,$(UPDATE)),--skip-tags sedge_update,) \
		$(VERBOSITY)

.PHONY: vagrant-up vagrant-provision vagrant-deploy vagrant-halt vagrant-destroy vagrant-ssh

# Defaults can be overridden: make vagrant-deploy NETWORK=sepolia CL_CLIENT=lodestar SYNC_MODE=fast UPDATE=true RESET=false VAGRANT_SEDGE_DIR=/opt/sedge/local-deployment
NETWORK ?= sepolia
CL_CLIENT ?= lodestar
SYNC_MODE ?= fast
NON_VALIDATOR_MODE ?= true
UPDATE ?= true
RESET ?= false
VAGRANT_SEDGE_DIR ?= /opt/sedge/local-deployment

vagrant-up: ## Bring up the Vagrant VM (VirtualBox) and run provisioning
	@echo "Starting Vagrant VM (VirtualBox) ..."
	vagrant up --provider=virtualbox --provision || true

vagrant-provision: ## Re-run provisioning on the Vagrant VM
	vagrant provision

vagrant-deploy: ## Provision the VM with Ansible (ansible_local) and run playbook-local-sedge.yml
	@echo "Deploying via Vagrant ansible_local: NETWORK=$(NETWORK), CL_CLIENT=$(CL_CLIENT), SYNC_MODE=$(SYNC_MODE), UPDATE=$(UPDATE)"
			NETWORK=$(NETWORK) CL_CLIENT=$(CL_CLIENT) SYNC_MODE=$(SYNC_MODE) NON_VALIDATOR_MODE=$(NON_VALIDATOR_MODE) RESET=$(RESET) VAGRANT_SEDGE_DIR=$(VAGRANT_SEDGE_DIR) \
		ANSIBLE_LOCAL_ARGS="$(if $(filter-out true,$(UPDATE)),--skip-tags sedge_update,) $(VERBOSITY)" \
   	  	vagrant provision --provision-with sedge_ansible 2>&1 | tee .vagrant/ansible_local_provision.log
	@echo "Saved ansible_local log to .vagrant/ansible_local_provision.log"

vagrant-halt: ## Stop the Vagrant VM
	vagrant halt

vagrant-destroy: ## Destroy the Vagrant VM
	vagrant destroy -f

vagrant-ssh: ## Open SSH session to the Vagrant VM
	vagrant ssh

# Proxmox deployment target
# Usage example:
# make proxmox-deploy NETWORK=chiado CL_CLIENT=lodestar SYNC_MODE=fast RESET=true PROXMOX_HOST_NAME=vm-chiado PROXMOX_HOST=10.0.0.50 PROXMOX_USER=ubuntu SEDGE_DIR=/opt/sedge/local-deployment
PROXMOX_HOST_NAME ?= vm-ethnode
PROXMOX_HOST ?=
PROXMOX_USER ?= ubuntu
SEDGE_DIR ?= /opt/sedge/local-deployment

proxmox-deploy: install ## Create/ensure Proxmox VM(s) and deploy node inside
	@echo -e "$(BLUE)Provisioning Proxmox VM(s) via API (optional) ...$(NC)"
	$(ANSIBLE_PLAYBOOK) playbook-proxmox.yml $(VERBOSITY) || true
	@echo -e "$(BLUE)Updating inventory with provided Proxmox host ...$(NC)"
	@if [ -n "$(PROXMOX_HOST)" ]; then \
		awk '1; $$0=="[proxmox]"{p=1; print; next} p&&/^$$/{p=0} p{next}' inventory.ini > inventory.tmp && mv inventory.tmp inventory.ini; \
		echo "[proxmox]" >> inventory.ini; \
		echo "$(PROXMOX_HOST_NAME) ansible_host=$(PROXMOX_HOST) ansible_user=$(PROXMOX_USER) ansible_python_interpreter=/usr/bin/python3" >> inventory.ini; \
	fi
	@echo -e "$(BLUE)Ensuring Docker & deps installed on Proxmox host and running Sedge ...$(NC)"
	$(ANSIBLE_PLAYBOOK) -i inventory.ini playbook-proxmox-run.yml \
		-e "target_host=$(PROXMOX_HOST_NAME)" \
		-e "network=$(NETWORK)" \
		-e "cl_client=$(CL_CLIENT)" \
		-e "sync_mode=$(SYNC_MODE)" \
		-e "non_validator_mode=$(NON_VALIDATOR_MODE)" \
		-e "reset=$(RESET)" \
		-e "sedge_data_dir=$(SEDGE_DIR)" \
		$(VERBOSITY) 