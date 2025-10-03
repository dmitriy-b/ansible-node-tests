#!/bin/bash
# Example: Run playbook-proxmox-lxc.yml with llama.cpp installation
#
# This script demonstrates how to enable llama.cpp installation
# in Proxmox LXC containers using the playbook.

set -e

# =============================================================================
# Proxmox Connection Configuration
# =============================================================================

# Proxmox API host (IP or hostname)
export PROXMOX_API_HOST="${PROXMOX_API_HOST:-192.168.1.100}"
export PROXMOX_API_PORT="${PROXMOX_API_PORT:-8006}"
export PROXMOX_VALIDATE_CERTS="${PROXMOX_VALIDATE_CERTS:-false}"

# Authentication: Use either token OR username/password

# Option 1: API Token (recommended)
export PROXMOX_API_TOKEN_ID="${PROXMOX_API_TOKEN_ID:-root@pam!ansible}"
export PROXMOX_API_TOKEN_SECRET="${PROXMOX_API_TOKEN_SECRET:-your-token-secret-here}"

# Option 2: Username/Password (alternative)
# export PROXMOX_API_USER="root@pam"
# export PROXMOX_API_PASSWORD="your-password"

# =============================================================================
# Proxmox Node and Storage Configuration
# =============================================================================

export PROXMOX_NODE="${PROXMOX_NODE:-pve}"
export PROXMOX_STORAGE="${PROXMOX_STORAGE:-local-lvm}"
export PROXMOX_CT_TEMPLATE_STORAGE="${PROXMOX_CT_TEMPLATE_STORAGE:-local}"
export PROXMOX_CT_TEMPLATE="${PROXMOX_CT_TEMPLATE:-ubuntu-22.04-standard_22.04-1_amd64.tar.zst}"

# =============================================================================
# Container Configuration
# =============================================================================

# Define container(s) to create
# Increase memory/cores for better llama.cpp performance
export PROXMOX_CTS_JSON='[
  {
    "hostname": "llama-ct-01",
    "vmid": 301,
    "cores": 4,
    "memory": 8192,
    "disk_gb": 30,
    "ip": "dhcp",
    "net_bridge": "vmbr0"
  }
]'

# Container defaults
export PROXMOX_CT_UNPRIVILEGED="${PROXMOX_CT_UNPRIVILEGED:-true}"
export PROXMOX_CT_NESTING="${PROXMOX_CT_NESTING:-true}"
export PROXMOX_CT_SWAP_MB="${PROXMOX_CT_SWAP_MB:-512}"

# Root password (optional - SSH keys are recommended)
# export CT_PASSWORD="your-secure-password"

# SSH key for container access (auto-detected if not set)
# export CT_SSH_AUTHORIZED_KEYS="$(cat ~/.ssh/id_ed25519.pub)"

# =============================================================================
# llama.cpp Installation Configuration
# =============================================================================

# Enable llama.cpp installation
export INSTALL_LLAMA_CPP=true

# Repository and version
export LLAMA_CPP_REPO_URL="https://github.com/ggml-org/llama.cpp"
export LLAMA_CPP_VERSION="master"  # or specific commit: "b3000"

# Installation directory inside container
export LLAMA_CPP_INSTALL_DIR="/opt/llama.cpp"

# Build configuration
export LLAMA_CPP_BUILD_TYPE="Release"  # or "Debug"
export LLAMA_CPP_BUILD_SERVER=true     # Build HTTP server
export LLAMA_CPP_ENABLE_CUBLAS=false   # CUDA/GPU support (requires NVIDIA GPU)
export LLAMA_CPP_ENABLE_METAL=false    # Metal support (Apple Silicon - N/A in LXC)

# =============================================================================
# SSH Configuration for Proxmox Host Access
# =============================================================================

export PROXMOX_FETCH_IP_VIA_SSH="${PROXMOX_FETCH_IP_VIA_SSH:-true}"
export PROXMOX_SSH_USER="${PROXMOX_SSH_USER:-root}"
export PROXMOX_SSH_PORT="${PROXMOX_SSH_PORT:-22}"
# export PROXMOX_SSH_KEY_PATH="${HOME}/.ssh/id_rsa"

# =============================================================================
# Run Playbook
# =============================================================================

echo "=========================================="
echo "Proxmox LXC + llama.cpp Installation"
echo "=========================================="
echo "Host: ${PROXMOX_API_HOST}"
echo "Node: ${PROXMOX_NODE}"
echo "Install llama.cpp: ${INSTALL_LLAMA_CPP}"
echo "llama.cpp version: ${LLAMA_CPP_VERSION}"
echo "Installation dir: ${LLAMA_CPP_INSTALL_DIR}"
echo "=========================================="
echo

# Check if playbook exists
if [ ! -f "playbook-proxmox-lxc.yml" ]; then
    echo "ERROR: playbook-proxmox-lxc.yml not found in current directory"
    exit 1
fi

# Run the playbook
ansible-playbook playbook-proxmox-lxc.yml "$@"

echo
echo "=========================================="
echo "Installation Complete!"
echo "=========================================="
echo
echo "Next steps:"
echo "1. SSH into your container:"
echo "   ssh root@<container-ip>  # Get IP from playbook output"
echo
echo "2. View usage instructions:"
echo "   cat ${LLAMA_CPP_INSTALL_DIR}/USAGE.txt"
echo
echo "3. Download a model:"
echo "   cd ${LLAMA_CPP_INSTALL_DIR}"
echo "   wget https://huggingface.co/TheBloke/Llama-2-7B-GGUF/resolve/main/llama-2-7b.Q4_K_M.gguf"
echo
echo "4. Run inference:"
echo "   ${LLAMA_CPP_INSTALL_DIR}/build/bin/main -m llama-2-7b.Q4_K_M.gguf -p 'Hello!' -n 50"
echo
echo "5. Start HTTP server:"
echo "   ${LLAMA_CPP_INSTALL_DIR}/build/bin/server -m llama-2-7b.Q4_K_M.gguf --host 0.0.0.0 --port 8080"
echo
echo "=========================================="


