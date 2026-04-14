#!/bin/bash
exec > >(tee /var/log/user-data.log | logger -t user-data -s 2>/dev/console) 2>&1
set -euxo pipefail

echo "=== install ssm agent ==="
dnf install -y https://s3.amazonaws.com/ec2-downloads-windows/SSMAgent/latest/linux_amd64/amazon-ssm-agent.rpm

echo "=== before packages ==="
systemctl is-enabled amazon-ssm-agent || true
systemctl status amazon-ssm-agent --no-pager || true

dnf install -y jq nmap-ncat postgresql17

echo "=== after packages ==="
systemctl daemon-reload || true
systemctl enable amazon-ssm-agent || true
systemctl restart amazon-ssm-agent || true
systemctl status amazon-ssm-agent --no-pager || true
journalctl -u amazon-ssm-agent -n 100 --no-pager || true
