#!/bin/bash
# =============================================================================
# SETUP SCRIPT — Builds the entire auto-scaling infrastructure on GCP
# Run this script once and it creates everything from scratch
#
# What this script builds:
#   1. Instance Template   → Blueprint for VMs
#   2. Health Check        → How GCP checks if a VM is alive
#   3. Managed Instance Group (MIG) → Group of identical VMs
#   4. Auto-Scaling Policy → Rules for when to add/remove VMs
#   5. Load Balancer       → Single entry point that distributes traffic
# =============================================================================

set -e  # Stop if any command fails

# =============================================================================
# CONFIGURATION — Change these values to match your GCP project
# =============================================================================
PROJECT_ID="your-project-id"          # Replace with your GCP Project ID
REGION="us-central1"                  # Region where resources are created
ZONE="us-central1-a"                  # Zone inside the region
TEMPLATE_NAME="nginx-template"        # Name for the instance template
MIG_NAME="nginx-mig"                  # Name for the managed instance group
HEALTH_CHECK_NAME="nginx-health-check" # Name for the health check
BACKEND_SERVICE_NAME="nginx-backend"  # Name for load balancer backend
URL_MAP_NAME="nginx-url-map"          # Name for URL routing rules
PROXY_NAME="nginx-http-proxy"         # Name for HTTP proxy
FORWARDING_RULE_NAME="nginx-lb-rule"  # Name for the forwarding rule (public IP)
FIREWALL_RULE_NAME="allow-http"       # Name for the firewall rule

# Colors for output (makes it easier to read)
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Helper function to print section headers
print_step() {
    echo ""
    echo -e "${BLUE}============================================${NC}"
    echo -e "${BLUE}  $1${NC}"
    echo -e "${BLUE}============================================${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_info() {
    echo -e "${YELLOW}ℹ️  $1${NC}"
}

print_skip() {
    echo -e "${YELLOW}⏭️  SKIPPING: $1 already exists. Moving forward.${NC}"
}

# =============================================================================
# HELPER: CHECK IF A RESOURCE ALREADY EXISTS
#
# How it works:
#   - Runs a "describe" command silently (no output)
#   - If the resource EXISTS  → describe succeeds (exit code 0) → returns true
#   - If the resource MISSING → describe fails   (exit code 1) → returns false
#
# Usage:
#   if resource_exists "gcloud compute firewall-rules describe my-rule"; then
#       echo "Already exists — skip"
#   else
#       echo "Does not exist — create it"
#   fi
# =============================================================================
resource_exists() {
    # Run the describe command, suppress ALL output (stdout + stderr)
    # We only care about the exit code: 0 = exists, 1 = does not exist
    eval "$1" --project=$PROJECT_ID > /dev/null 2>&1
}

# =============================================================================
# STEP 0: SET GCP PROJECT
# =============================================================================
print_step "STEP 0: Setting GCP Project"
gcloud config set project $PROJECT_ID
print_success "Project set to: $PROJECT_ID"

# =============================================================================
# STEP 1: CREATE FIREWALL RULE
# By default, GCP blocks all incoming traffic.
# We need to allow HTTP (port 80) traffic to reach our VMs.
# We also tag VMs with "http-server" and apply the rule to that tag.
# =============================================================================
print_step "STEP 1: Creating Firewall Rule (Allow HTTP on port 80)"

if resource_exists "gcloud compute firewall-rules describe $FIREWALL_RULE_NAME"; then
    print_skip "$FIREWALL_RULE_NAME"
else
    gcloud compute firewall-rules create $FIREWALL_RULE_NAME \
      --project=$PROJECT_ID \
      --direction=INGRESS \
      --priority=1000 \
      --network=default \
      --action=ALLOW \
      --rules=tcp:80 \
      --source-ranges=0.0.0.0/0 \
      --target-tags=http-server \
      --description="Allow HTTP traffic to web servers"
    print_success "Firewall rule created: port 80 is now open"
fi

# =============================================================================
# STEP 2: CREATE INSTANCE TEMPLATE
#
# Think of this as a COOKIE CUTTER.
# It defines exactly what every VM should look like:
#   - Which operating system (Debian 11)
#   - How powerful (e2-medium: 2 vCPU, 4GB RAM)
#   - What software to install (nginx via startup script)
#
# When MIG needs to create a new VM, it uses this template.
# All VMs are IDENTICAL — same OS, same software, same config.
# =============================================================================
print_step "STEP 2: Creating Instance Template"
print_info "This is the blueprint. Every VM the MIG creates will use this template."

if resource_exists "gcloud compute instance-templates describe $TEMPLATE_NAME"; then
    print_skip "$TEMPLATE_NAME"
else
    gcloud compute instance-templates create $TEMPLATE_NAME \
      --project=$PROJECT_ID \
      --machine-type=e2-medium \
      --image-family=debian-11 \
      --image-project=debian-cloud \
      --boot-disk-size=20GB \
      --boot-disk-type=pd-balanced \
      --tags=http-server \
      --metadata-from-file=startup-script=startup-script.sh \
      --description="Template for nginx web server with auto-scaling"
    print_success "Instance template created: $TEMPLATE_NAME"
    print_info "Every VM created from this template will automatically install nginx"
fi

# =============================================================================
# STEP 3: CREATE HEALTH CHECK
#
# The health check is GCP's way of asking: "Are you alive and working?"
# Every 10 seconds, GCP sends an HTTP request to /health on port 80.
#
# If VM responds with HTTP 200 → It's HEALTHY → Stays in the pool
# If VM doesn't respond (3 times in a row) → It's UNHEALTHY → Gets REPLACED
#
# This is how auto-healing works — sick VMs are automatically replaced.
# =============================================================================
print_step "STEP 3: Creating Health Check"
print_info "GCP will ping / (nginx default page) every 10 seconds to verify VMs are alive"

if resource_exists "gcloud compute health-checks describe $HEALTH_CHECK_NAME"; then
    print_skip "$HEALTH_CHECK_NAME"
else
    gcloud compute health-checks create http $HEALTH_CHECK_NAME \
      --project=$PROJECT_ID \
      --port=80 \
      --request-path=/ \
      --check-interval=10s \
      --timeout=10s \
      --healthy-threshold=5 \
      --unhealthy-threshold=5 \
      --description="HTTP health check for nginx VMs"

    # What these numbers mean:
    # --check-interval=10s      → Check every 10 seconds
    # --timeout=10s             → Wait up to 10 seconds for a response before marking as failed
    #                             (set equal to interval so we never have overlapping checks)
    # --healthy-threshold=5     → Need 5 consecutive successes to mark VM as HEALTHY
    #                             (prevents a VM from entering the pool too soon after boot)
    # --unhealthy-threshold=5   → Need 5 consecutive failures to mark VM as UNHEALTHY
    #                             (prevents a VM from being replaced due to a brief glitch)
    # --request-path=/          → Pings nginx default page — returns HTTP 200 when nginx is up
    print_success "Health check created: $HEALTH_CHECK_NAME"
fi

# =============================================================================
# STEP 4: CREATE MANAGED INSTANCE GROUP (MIG)
#
# The MIG is the MANAGER. It:
#   1. Creates VMs using the template we defined
#   2. Keeps a minimum number of VMs always running (base capacity)
#   3. Watches the health check — replaces sick VMs automatically
#   4. Adds new VMs when auto-scaling says "need more capacity"
#   5. Removes VMs when auto-scaling says "too many VMs"
#
# We start with 1 VM. Auto-scaling will add more when traffic increases.
# =============================================================================
print_step "STEP 4: Creating Managed Instance Group"
print_info "Starting with 2 VMs. Auto-scaler will add more when CPU > 70%"

if resource_exists "gcloud compute instance-groups managed describe $MIG_NAME --zone=$ZONE"; then
    print_skip "$MIG_NAME"
else
    gcloud compute instance-groups managed create $MIG_NAME \
      --project=$PROJECT_ID \
      --base-instance-name=nginx-web \
      --template=$TEMPLATE_NAME \
      --size=2 \
      --zone=$ZONE \
      --health-checks=$HEALTH_CHECK_NAME \
      --initial-delay=300s \
      --description="Managed instance group for auto-scaling nginx web servers"

    # --base-instance-name=nginx-web → VMs will be named nginx-web-xxxx (random suffix)
    # --size=2                       → Start with 2 VMs (minimum baseline capacity)
    # --health-checks                → Attach the health check we just created
    # --initial-delay=300s           → Wait 300 seconds (5 minutes) before running the first
    #                                  health check on a new VM — gives the startup script
    #                                  enough time to fully install and start nginx before
    #                                  GCP starts evaluating if the VM is healthy
    print_success "MIG created with 2 initial VMs"
    print_info "VMs are booting and running startup script (takes ~3-5 minutes)..."
fi

# =============================================================================
# STEP 5: SET AUTO-SCALING POLICY
#
# This is where the INTELLIGENCE lives. We tell GCP:
# "Watch the average CPU usage across all VMs.
#  If average CPU > 70% → Create more VMs (we're getting too much traffic)
#  If average CPU < 70% → Remove VMs (traffic is low, save money)
#  Always keep at least 2 VMs running (baseline availability)
#  Never create more than 5 VMs (cost control)"
#
# GCP checks this every 60 seconds and adjusts automatically.
# =============================================================================
print_step "STEP 5: Configuring Auto-Scaling Policy"
print_info "Scale UP when CPU > 70% | Scale DOWN when CPU < 70% | Min=2 VMs | Max=5 VMs"

gcloud compute instance-groups managed set-autoscaling $MIG_NAME \
  --project=$PROJECT_ID \
  --zone=$ZONE \
  --min-num-replicas=2 \
  --max-num-replicas=5 \
  --target-cpu-utilization=0.7 \
  --cool-down-period=90 \
  --scale-in-control=max-scaled-in-replicas=1,time-window=120s \
  --description="Auto-scale based on CPU: target 70% utilization, min 2 VMs, max 5 VMs"

# --min-num-replicas=2            → Always keep at least 2 VMs running
#                                   (even at zero traffic — ensures baseline availability)
# --max-num-replicas=5            → Never exceed 5 VMs (hard cost ceiling)
# --target-cpu-utilization=0.7    → Target 70% CPU across all VMs
#                                   Add VMs when above 70%, remove when below 70%
# --cool-down-period=90           → Wait 90 seconds after adding a VM before adding another
#                                   (gives the new VM time to boot and start taking traffic
#                                   before the auto-scaler re-evaluates the CPU average)
# --scale-in-control              → When scaling down, remove max 1 VM per 2 minutes
#                                   (gradual removal prevents sudden capacity drops)

print_success "Auto-scaling configured"
print_info "GCP will automatically manage VM count based on traffic"

# =============================================================================
# STEP 6: CREATE LOAD BALANCER
#
# The Load Balancer is the FRONT DOOR. It:
#   - Has a single public IP address (your users hit this IP)
#   - Receives all incoming HTTP requests
#   - Distributes them evenly across healthy VMs
#   - If a VM is unhealthy (failed health check) → stops sending traffic to it
#
# A GCP HTTP Load Balancer has multiple components:
#   Backend Service  → Defines WHERE traffic goes (our MIG)
#   URL Map          → Defines ROUTING rules (/* → backend service)
#   HTTP Proxy       → Handles HTTP protocol
#   Forwarding Rule  → Public IP → HTTP Proxy (the entry point)
# =============================================================================
print_step "STEP 6: Creating Load Balancer"

# PART A: Add named port to MIG
# set-named-ports is naturally idempotent — safe to run every time
# It simply updates the port mapping, so no check needed here
print_info "Part A: Setting named port (http:80) on MIG..."
gcloud compute instance-groups managed set-named-ports $MIG_NAME \
  --project=$PROJECT_ID \
  --zone=$ZONE \
  --named-ports=http:80
print_success "Named port set"

# PART B: Create Backend Service
print_info "Part B: Creating backend service..."
if resource_exists "gcloud compute backend-services describe $BACKEND_SERVICE_NAME --global"; then
    print_skip "$BACKEND_SERVICE_NAME"
else
    gcloud compute backend-services create $BACKEND_SERVICE_NAME \
      --project=$PROJECT_ID \
      --protocol=HTTP \
      --port-name=http \
      --health-checks=$HEALTH_CHECK_NAME \
      --global \
      --enable-logging \
      --logging-sample-rate=1.0 \
      --description="Backend service for nginx auto-scaling MIG"
    print_success "Backend service created: $BACKEND_SERVICE_NAME"

    # Attach MIG to backend service
    # This is inside the else block — only attach when backend service is newly created
    # If backend service already existed, the MIG is already attached
    print_info "Attaching MIG to backend service..."
    gcloud compute backend-services add-backend $BACKEND_SERVICE_NAME \
      --project=$PROJECT_ID \
      --instance-group=$MIG_NAME \
      --instance-group-zone=$ZONE \
      --balancing-mode=UTILIZATION \
      --max-utilization=0.8 \
      --global
    print_success "MIG attached to backend service"
fi

# PART C: Create URL Map
print_info "Part C: Creating URL map (routing rules)..."
if resource_exists "gcloud compute url-maps describe $URL_MAP_NAME"; then
    print_skip "$URL_MAP_NAME"
else
    gcloud compute url-maps create $URL_MAP_NAME \
      --project=$PROJECT_ID \
      --default-service=$BACKEND_SERVICE_NAME \
      --description="Route all traffic to nginx backend"
    print_success "URL map created: $URL_MAP_NAME"
fi

# PART D: Create HTTP Proxy
print_info "Part D: Creating HTTP proxy..."
if resource_exists "gcloud compute target-http-proxies describe $PROXY_NAME"; then
    print_skip "$PROXY_NAME"
else
    gcloud compute target-http-proxies create $PROXY_NAME \
      --project=$PROJECT_ID \
      --url-map=$URL_MAP_NAME \
      --description="HTTP proxy for nginx load balancer"
    print_success "HTTP proxy created: $PROXY_NAME"
fi

# PART E: Create Forwarding Rule (Public IP)
print_info "Part E: Creating forwarding rule (assigning public IP)..."
if resource_exists "gcloud compute forwarding-rules describe $FORWARDING_RULE_NAME --global"; then
    print_skip "$FORWARDING_RULE_NAME"
else
    gcloud compute forwarding-rules create $FORWARDING_RULE_NAME \
      --project=$PROJECT_ID \
      --global \
      --target-http-proxy=$PROXY_NAME \
      --ports=80 \
      --description="Global forwarding rule for nginx load balancer"
    print_success "Forwarding rule created with public IP"
fi

# =============================================================================
# STEP 7: GET THE PUBLIC IP ADDRESS
# =============================================================================
print_step "STEP 7: Getting Public IP Address"

LB_IP=$(gcloud compute forwarding-rules describe $FORWARDING_RULE_NAME \
  --project=$PROJECT_ID \
  --global \
  --format="get(IPAddress)")

print_success "Load Balancer IP: $LB_IP"

# =============================================================================
# FINAL SUMMARY
# =============================================================================
echo ""
echo -e "${GREEN}============================================${NC}"
echo -e "${GREEN}  🎉 INFRASTRUCTURE SETUP COMPLETE!        ${NC}"
echo -e "${GREEN}============================================${NC}"
echo ""
echo -e "${YELLOW}Resources created:${NC}"
echo "  • Firewall Rule:     $FIREWALL_RULE_NAME"
echo "  • Instance Template: $TEMPLATE_NAME"
echo "  • Health Check:      $HEALTH_CHECK_NAME"
echo "  • Instance Group:    $MIG_NAME (Zone: $ZONE)"
echo "  • Auto-Scaling:      Min=2 VMs, Max=5 VMs, Target CPU=70%"
echo "  • Backend Service:   $BACKEND_SERVICE_NAME"
echo "  • Load Balancer IP:  $LB_IP"
echo ""
echo -e "${YELLOW}⏳ Important: Wait 3-5 minutes before accessing the URL${NC}"
echo -e "${YELLOW}   Reason: VMs are booting + startup script is running + LB is provisioning${NC}"
echo ""
echo -e "${GREEN}🌐 Your website:  http://$LB_IP${NC}"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "  1. Wait 5 minutes for everything to be ready"
echo "  2. Visit http://$LB_IP in your browser"
echo "  3. Run stress test: ./stress-test.sh $LB_IP"
echo "  4. Watch VMs scale: gcloud compute instance-groups managed list-instances $MIG_NAME --zone=$ZONE"
echo ""
echo -e "${RED}💰 Remember to run ./teardown.sh when done to avoid charges!${NC}"
