#!/bin/bash
# =============================================================================
# TEARDOWN SCRIPT — Deletes ALL resources created by setup.sh
#
# Run this when you're done with the project to avoid GCP charges.
# This deletes everything in the correct order (dependencies first).
# =============================================================================

PROJECT_ID="your-project-id"
REGION="us-central1"
ZONE="us-central1-a"

echo "============================================"
echo "  ⚠️  TEARDOWN — Deleting All Resources"
echo "============================================"
echo ""
echo "This will DELETE the following resources:"
echo "  • Forwarding Rule:   nginx-lb-rule"
echo "  • HTTP Proxy:        nginx-http-proxy"
echo "  • URL Map:           nginx-url-map"
echo "  • Backend Service:   nginx-backend"
echo "  • Instance Group:    nginx-mig"
echo "  • Health Check:      nginx-health-check"
echo "  • Instance Template: nginx-template"
echo "  • Firewall Rule:     allow-http"
echo ""
read -p "Are you sure? (yes/no): " CONFIRM
if [ "$CONFIRM" != "yes" ]; then
    echo "Teardown cancelled."
    exit 0
fi

echo ""
echo "Deleting resources (order matters — delete dependent resources first)..."

# Delete in reverse order of creation (dependencies must go first)
echo "1. Deleting Forwarding Rule..."
gcloud compute forwarding-rules delete nginx-lb-rule --global --quiet
echo "   ✅ Done"

echo "2. Deleting HTTP Proxy..."
gcloud compute target-http-proxies delete nginx-http-proxy --quiet
echo "   ✅ Done"

echo "3. Deleting URL Map..."
gcloud compute url-maps delete nginx-url-map --quiet
echo "   ✅ Done"

echo "4. Deleting Backend Service..."
gcloud compute backend-services delete nginx-backend --global --quiet
echo "   ✅ Done"

echo "5. Deleting Managed Instance Group (this also deletes all VMs)..."
gcloud compute instance-groups managed delete nginx-mig --zone=$ZONE --quiet
echo "   ✅ Done"

echo "6. Deleting Health Check..."
gcloud compute health-checks delete nginx-health-check --quiet
echo "   ✅ Done"

echo "7. Deleting Instance Template..."
gcloud compute instance-templates delete nginx-template --quiet
echo "   ✅ Done"

echo "8. Deleting Firewall Rule..."
gcloud compute firewall-rules delete allow-http --quiet
echo "   ✅ Done"

echo ""
echo "============================================"
echo "  ✅ ALL RESOURCES DELETED"
echo "  No more charges will occur for this project"
echo "============================================"
