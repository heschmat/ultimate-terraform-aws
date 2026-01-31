#!/bin/bash
set -euo pipefail

# Update system
dnf update -y

# Install useful networking/debug tools
dnf install -y \
  curl \
  wget \
  bind-utils \
  nc \
  traceroute \
  jq \
  tcpdump

# Ensure SSM agent is running (already installed on AL2023)
systemctl enable amazon-ssm-agent
systemctl restart amazon-ssm-agent

# Explicit networking tests
{
  echo "=== BOOTSTRAP COMPLETE ==="
  date

  echo "=== DNS TEST ==="
  dig amazon.com +short

  echo "=== HTTPS TEST ==="
  curl -I https://www.amazon.com

  echo "=== METADATA TEST ==="
  curl -s http://169.254.169.254/latest/meta-data/instance-id

  echo "=== NAT PUBLIC IP ==="
  curl -s https://checkip.amazonaws.com
} > /var/log/network-test.log
