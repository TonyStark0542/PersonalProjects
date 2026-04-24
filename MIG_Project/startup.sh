#!/bin/bash
# =============================================================================
# STARTUP SCRIPT — Runs automatically when a new VM boots
# GCP injects this script and runs it as root on every VM instance
# =============================================================================

set -e  # Stop script if any command fails
set -x  # Print every command before running it (useful for debugging)

# Step 1: Update the package list so we get the latest nginx
apt-get update -y

# Step 2: Install nginx web server
apt-get install -y nginx

# Step 3: Install stress tool — we use this later for CPU load testing
apt-get install -y stress

# Step 4: Start nginx immediately
systemctl start nginx

# Step 5: Enable nginx to auto-start whenever the VM reboots
systemctl enable nginx

# Step 6: Get this VM's hostname (each VM gets a unique name like "web-server-abc1")
HOSTNAME=$(hostname)

# Step 7: Get the VM's internal IP address
INTERNAL_IP=$(hostname -I | awk '{print $1}')

# Step 8: Get the VM's zone from GCP metadata server
# The metadata server is a special internal endpoint at 169.254.169.254
# It gives us information about the VM (zone, project, etc.)
ZONE=$(curl -s "http://metadata.google.internal/computeMetadata/v1/instance/zone" \
  -H "Metadata-Flavor: Google" | awk -F'/' '{print $NF}')

# Step 9: Create a custom HTML page so we can see WHICH VM served the request
# This is important during load testing — we can see requests spreading across VMs
cat > /var/www/html/index.html << EOF
<!DOCTYPE html>
<html>
<head>
    <title>GCP Auto-Scaling Demo</title>
    <style>
        body {
            font-family: Arial, sans-serif;
            background-color: #f0f4f8;
            display: flex;
            justify-content: center;
            align-items: center;
            height: 100vh;
            margin: 0;
        }
        .card {
            background: white;
            border-radius: 12px;
            padding: 40px;
            box-shadow: 0 4px 20px rgba(0,0,0,0.1);
            text-align: center;
            max-width: 500px;
        }
        .hostname { color: #4285f4; font-size: 24px; font-weight: bold; }
        .label { color: #666; font-size: 14px; margin-top: 4px; }
        .value { color: #333; font-size: 16px; font-weight: 500; }
        .badge {
            background: #34a853;
            color: white;
            padding: 6px 16px;
            border-radius: 20px;
            font-size: 13px;
            display: inline-block;
            margin-top: 20px;
        }
    </style>
</head>
<body>
    <div class="card">
        <h1>Auto-Scaling Demo</h1>
        <div class="hostname">$HOSTNAME</div>
        <div class="label">VM Hostname (changes with each VM)</div>
        <br>
        <div class="label">Internal IP</div>
        <div class="value">$INTERNAL_IP</div>
        <br>
        <div class="label">Zone</div>
        <div class="value">$ZONE</div>
        <br>
        <div class="badge">Healthy &amp; Serving Traffic</div>
        <p style="color:#999; font-size:12px; margin-top:20px;">
            This VM was auto-created by the Managed Instance Group
        </p>
    </div>
</body>
</html>
EOF

# Step 10: Log the startup completion with timestamp
echo "[$(date)] Startup script completed. Nginx is running on $HOSTNAME" \
  >> /var/log/startup-script.log

echo "=== STARTUP COMPLETE ==="
echo "Hostname: $HOSTNAME"
echo "Zone: $ZONE"
echo "Nginx status: $(systemctl is-active nginx)"
