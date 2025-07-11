#!/bin/bash

# Exit on error
set -e

# Update and install dependencies
sudo apt update
sudo apt install -y python3 python3-pip python3-venv git nodejs npm yarn mariadb-server redis-server curl

# Create a directory for your codex environment
mkdir -p ~/codex_env
cd ~/codex_env

# Set up Python virtual environment
python3 -m venv venv
source venv/bin/activate

# Upgrade pip
pip install --upgrade pip

# Install Frappe Bench
pip install frappe-bench

# Add bench to PATH if needed (optional)
export PATH="$HOME/.local/bin:$PATH"

# Verify bench installation
bench --version

# Initialize Frappe Bench (replace 'frappe-bench' with your desired directory name)
bench init frappe-bench

echo "Frappe Bench setup complete in ~/codex_env/frappe-bench"
