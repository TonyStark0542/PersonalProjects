#!/bin/bash
# =============================================================================
# STRESS TEST SCRIPT
# Uses Apache Benchmark (ab) to hammer the load balancer with requests
# This causes CPU to spike → triggers auto-scaling → new VMs appear
#
# Usage: ./stress-test.sh <LOAD_BALANCER_IP>
# Example: ./stress-test.sh 34.120.45.67
# =============================================================================

LB_IP=$1

if [ -z "$LB_IP" ]; then
    echo "❌ Error: Please provide the Load Balancer IP"
    echo "Usage: ./stress-test.sh <LOAD_BALANCER_IP>"
    echo ""
    echo "Get your LB IP by running:"
    echo "  gcloud compute forwarding-rules describe nginx-lb-rule --global --format='get(IPAddress)'"
    exit 1
fi

# Configuration
MIG_NAME="nginx-mig"
ZONE="us-central1-a"

echo "============================================"
echo "  🔥 STRESS TEST — GCP AUTO-SCALING DEMO"
echo "============================================"
echo ""
echo "Target URL:  http://$LB_IP"
echo "MIG Name:    $MIG_NAME"
echo ""
echo "This test will:"
echo "  1. Send 10,000 requests to your load balancer"
echo "  2. This spikes CPU on VMs above 60%"
echo "  3. Auto-scaler detects high CPU"
echo "  4. New VMs are created automatically"
echo "  5. You can watch it happen in real-time"
echo ""

# Check if ab (Apache Benchmark) is installed
if ! command -v ab &> /dev/null; then
    echo "Installing Apache Benchmark (ab)..."
    sudo apt-get install -y apache2-utils
fi

# Show current VM count before test
echo "============================================"
echo "📊 CURRENT VM COUNT (BEFORE STRESS TEST)"
echo "============================================"
gcloud compute instance-groups managed list-instances $MIG_NAME \
  --zone=$ZONE \
  --format="table(name,status,currentAction)"
echo ""

# First: Test the load balancer is reachable
echo "🔍 Verifying load balancer is reachable..."
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "http://$LB_IP/health")
if [ "$HTTP_CODE" != "200" ]; then
    echo "❌ Load balancer returned HTTP $HTTP_CODE"
    echo "   Make sure setup is complete and wait 5 minutes after running setup.sh"
    exit 1
fi
echo "✅ Load balancer is healthy (HTTP 200)"
echo ""

# =============================================================================
# PHASE 1: MODERATE LOAD
# Warm up with moderate requests
# =============================================================================
echo "============================================"
echo "  PHASE 1: MODERATE LOAD (WARM UP)"
echo "  1,000 requests | 10 concurrent"
echo "============================================"
ab -n 1000 -c 10 -q "http://$LB_IP/"
echo "✅ Phase 1 complete"
echo ""

# Wait and check
sleep 10
echo "📊 VM count after moderate load:"
gcloud compute instance-groups managed list-instances $MIG_NAME \
  --zone=$ZONE --format="table(name,status,currentAction)"
echo ""

# =============================================================================
# PHASE 2: HIGH LOAD
# This should trigger auto-scaling
# =============================================================================
echo "============================================"
echo "  PHASE 2: HIGH LOAD (TRIGGER AUTO-SCALE)"
echo "  10,000 requests | 100 concurrent"
echo "============================================"
echo "Watch for new VMs being created..."
echo ""

# Run stress test in background
ab -n 10000 -c 100 -q "http://$LB_IP/" &
AB_PID=$!

# While test runs, monitor VM count every 30 seconds
echo "📡 Monitoring VM count every 30 seconds..."
echo "   (Auto-scaler checks every 60 seconds, so wait a bit)"
echo ""
ELAPSED=0
while kill -0 $AB_PID 2>/dev/null; do
    sleep 30
    ELAPSED=$((ELAPSED + 30))
    echo "⏱️  Time elapsed: ${ELAPSED}s"
    echo "Current VMs:"
    gcloud compute instance-groups managed list-instances $MIG_NAME \
      --zone=$ZONE --format="table(name,status,currentAction)" 2>/dev/null
    echo ""
done

wait $AB_PID
echo "✅ Phase 2 complete — High load test finished"
echo ""

# =============================================================================
# PHASE 3: SUSTAINED LOAD
# Keep pressure up so auto-scaler adds more VMs
# =============================================================================
echo "============================================"
echo "  PHASE 3: SUSTAINED LOAD"
echo "  50,000 requests | 200 concurrent"
echo "  This will definitely trigger auto-scaling"
echo "============================================"

ab -n 50000 -c 200 "http://$LB_IP/" &
AB_PID=$!

# Monitor in foreground
for i in 1 2 3 4 5; do
    sleep 60
    echo "⏱️  Minute $i/5 elapsed"
    echo "📊 VM count:"
    gcloud compute instance-groups managed list-instances $MIG_NAME \
      --zone=$ZONE --format="table(name,status,currentAction)"
    echo ""
done

wait $AB_PID
echo "✅ Phase 3 complete"
echo ""

# =============================================================================
# FINAL RESULTS
# =============================================================================
echo "============================================"
echo "📊 FINAL VM COUNT (AFTER STRESS TEST)"
echo "============================================"
gcloud compute instance-groups managed list-instances $MIG_NAME \
  --zone=$ZONE \
  --format="table(name,status,currentAction)"

echo ""
echo "============================================"
echo "  ✅ STRESS TEST COMPLETE"
echo "============================================"
echo ""
echo "What happened:"
echo "  1. Started with minimum VMs"
echo "  2. Sent thousands of requests → CPU spiked above 60%"
echo "  3. Auto-scaler detected high CPU"
echo "  4. New VMs were automatically created"
echo "  5. Load balanced across all healthy VMs"
echo ""
echo "Now that traffic has stopped:"
echo "  - CPU on VMs will drop"
echo "  - After ~5 minutes, auto-scaler will start removing extra VMs"
echo "  - Eventually returns to minimum VM count"
echo ""
echo "To watch scale-down in real time:"
echo "  watch -n 30 'gcloud compute instance-groups managed list-instances $MIG_NAME --zone=$ZONE'"
echo ""
echo "💰 Don't forget to run ./teardown.sh when done!"
