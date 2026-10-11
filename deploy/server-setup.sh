#!/usr/bin/env bash
# One-time preparation of a fresh Ubuntu 24.04 EC2 instance (t3.micro) for `cap production deploy`.
# Run from your machine:   ssh -i ~/.ssh/salary-dashboard.pem ubuntu@<elastic-ip> 'bash -s' < deploy/server-setup.sh
# Safe to re-run: each step checks before changing anything, and an existing shared/.env is never overwritten.
set -euo pipefail

# 1. 2 GB swap: building the image (gems + React) needs more memory than the t3.micro's 1 GB.
if ! sudo swapon --show | grep -q /swapfile; then
  sudo fallocate -l 2G /swapfile
  sudo chmod 600 /swapfile
  sudo mkswap /swapfile
  sudo swapon /swapfile
  echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab > /dev/null
fi

# 2. Docker Engine, Compose and Buildx from Ubuntu's own packages; git and curl for Capistrano and the health check.
if ! command -v docker > /dev/null || ! docker compose version > /dev/null 2>&1; then
  sudo apt-get update -qq
  sudo apt-get install -y -qq docker.io docker-compose-v2 docker-buildx git curl
fi
sudo systemctl enable --now docker
sudo usermod -aG docker ubuntu   # takes effect at the next SSH login (Capistrano opens a new one)

# 3. Secrets, created once on the server only (never in git). Hex/base64 values: no shell or URL quoting issues.
shared="$HOME/salary-dashboard/shared"
mkdir -p "$shared"
if [ ! -f "$shared/.env" ]; then
  umask 077
  {
    echo "POSTGRES_PASSWORD=$(openssl rand -hex 24)"
    echo "SECRET_KEY_BASE=$(openssl rand -hex 64)"
    echo "DEMO_USER_PASSWORD=$(openssl rand -base64 18)"
    echo "FORCE_SSL=false"
  } > "$shared/.env"
  echo "Created $shared/.env. Demo sign-in password (save it now):"
  grep '^DEMO_USER_PASSWORD=' "$shared/.env" | cut -d= -f2-
else
  echo "$shared/.env already exists; left unchanged."
fi

echo "Server ready: $(docker --version) · $(docker compose version) · swap $(free -h | awk '/Swap/ {print $2}')"
