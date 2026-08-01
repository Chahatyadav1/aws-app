#!/usr/bin/env bash
# Builds and pushes a first ('latest') image to each ECR repo so the
# ECS services stack has something valid to launch on first deploy.
# Usage: ./push-initial-images.sh <environment-name> <aws-region>
set -euo pipefail

ENV_NAME="${1:-threetier-app}"
REGION="${2:-us-east-1}"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

aws ecr get-login-password --region "${REGION}" | \
  docker login --username AWS --password-stdin "${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com"

for TIER in backend frontend; do
  REPO="${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com/${ENV_NAME}-${TIER}"
  echo "== Building ${TIER} =="
  docker build -t "${REPO}:latest" "${ROOT_DIR}/app/${TIER}"
  docker push "${REPO}:latest"
done

echo "Initial images pushed. You can now deploy the ECS services stack."
