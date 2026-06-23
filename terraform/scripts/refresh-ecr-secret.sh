#!/bin/bash
# Run this ON the Kubernetes node (via SSH) whenever the ECR pull secret
# needs refreshing - ECR authorization tokens expire after ~12 hours.
# Uses the node's IAM instance role, so no credentials are stored anywhere.
set -euo pipefail

REGION="ap-south-1"
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
ECR_REGISTRY="${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com"

kubectl create secret docker-registry ecr-secret \
  --docker-server="${ECR_REGISTRY}" \
  --docker-username=AWS \
  --docker-password="$(aws ecr get-login-password --region "${REGION}")" \
  --dry-run=client -o yaml | kubectl apply -f -

echo "ECR pull secret refreshed for ${ECR_REGISTRY} (valid ~12 hours)."