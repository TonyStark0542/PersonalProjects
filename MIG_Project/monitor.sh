#!/bin/bash
# =============================================================================
# MONITOR SCRIPT — Watch auto-scaling happen in real time
# Run this in a separate terminal while running stress-test.sh
#
# Usage: ./monitor.sh
# =============================================================================

MIG_NAME="nginx-mig"
ZONE="us-central1-a"
LB_IP=$1

clear
echo "============================================"
echo "  📡 REAL-TIME AUTO-SCALING MONITOR"
echo "  Refreshes every 30 seconds"
echo "  Press Ctrl+C to stop"
echo "============================================"
echo ""

while true; do
    clear
    echo "============================================"
    echo "  📡 AUTO-SCALING MONITOR | $(date '+%H:%M:%S')"
    echo "============================================"
    echo ""

    # VM count and status
    echo "🖥️  VIRTUAL MACHINES:"
    gcloud compute instance-groups managed list-instances $MIG_NAME \
      --zone=$ZONE \
      --format="table(name,status,currentAction,lastAttempt.errors.errors[0].message)" \
      2>/dev/null
    echo ""

    # MIG status
    echo "📊 MIG STATUS:"
    gcloud compute instance-groups managed describe $MIG_NAME \
      --zone=$ZONE \
      --format="table(
        targetSize:label='TARGET VMs',
        currentActions.creating:label='CREATING',
        currentActions.deleting:label='DELETING',
        currentActions.recreating:label='RECREATING',
        currentActions.none:label='STABLE'
      )" 2>/dev/null
    echo ""

    # Auto-scaler status
    echo "⚖️  AUTO-SCALER STATUS:"
    gcloud compute instance-groups managed describe $MIG_NAME \
      --zone=$ZONE \
      --format="json" 2>/dev/null | python3 -c "
import json, sys
data = json.load(sys.stdin)
autoscaler = data.get('autoscaler', '')
print(f'  Autoscaler: {autoscaler}')
" 2>/dev/null || echo "  (auto-scaler info not available)"
    echo ""

    # Quick health check
    if [ ! -z "$LB_IP" ]; then
        echo "🌐 LOAD BALANCER HEALTH:"
        HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" --max-time 3 "http://$LB_IP/" 2>/dev/null)
        RESPONSE_TIME=$(curl -s -o /dev/null -w "%{time_total}" --max-time 3 "http://$LB_IP/" 2>/dev/null)
        echo "  HTTP Status:   $HTTP_CODE"
        echo "  Response Time: ${RESPONSE_TIME}s"
        echo ""
    fi

    echo "--------------------------------------------"
    echo "Auto-scaling rules:"
    echo "  Scale UP   → when CPU > 70%  (adds a VM)"
    echo "  Scale DOWN → when CPU < 30%  (removes a VM)"
    echo "  Min VMs: 2 | Max VMs: 5"
    echo ""
    echo "Refreshing in 30 seconds... (Ctrl+C to stop)"
    sleep 30
done
