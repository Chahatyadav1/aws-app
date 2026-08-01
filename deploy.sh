#!/usr/bin/env bash
# Deploys the 3-tier stack in the correct order.
# Usage: ./deploy.sh <environment-name> <aws-region>
set -euo pipefail

ENV_NAME="${1:-threetier-app}"
REGION="${2:-us-east-1}"
INFRA_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/infrastructure"

echo "== Deploying networking stack =="
aws cloudformation deploy \
  --stack-name "${ENV_NAME}-network" \
  --template-file "${INFRA_DIR}/01-network.yaml" \
  --parameter-overrides EnvironmentName="${ENV_NAME}" \
  --region "${REGION}"

echo "== Deploying database stack =="
aws cloudformation deploy \
  --stack-name "${ENV_NAME}-database" \
  --template-file "${INFRA_DIR}/02-database.yaml" \
  --parameter-overrides EnvironmentName="${ENV_NAME}" \
  --capabilities CAPABILITY_IAM \
  --region "${REGION}"

echo "== Deploying ECR / ALB / ECS cluster stack =="
aws cloudformation deploy \
  --stack-name "${ENV_NAME}-edge" \
  --template-file "${INFRA_DIR}/03-ecr-alb-cluster.yaml" \
  --parameter-overrides EnvironmentName="${ENV_NAME}" \
  --region "${REGION}"

cat <<MSG

== Manual step required ==
Before deploying ECS services, both ECR repositories need at least one
image tagged 'latest'. Run ./push-initial-images.sh ${ENV_NAME} ${REGION}
now, then re-run this script with the 'services' argument:

    ./deploy.sh ${ENV_NAME} ${REGION} services

MSG

if [[ "${3:-}" == "services" ]]; then
  echo "== Deploying ECS services stack =="
  aws cloudformation deploy \
    --stack-name "${ENV_NAME}-services" \
    --template-file "${INFRA_DIR}/04-ecs-services.yaml" \
    --parameter-overrides EnvironmentName="${ENV_NAME}" \
    --capabilities CAPABILITY_NAMED_IAM \
    --region "${REGION}"

  echo "== Deploying CI/CD pipeline stack =="
  read -rp "GitHub owner/org: " GH_OWNER
  read -rp "GitHub repo name: " GH_REPO
  read -rp "CodeStar Connection ARN (create + approve first, see README): " CONN_ARN
  aws cloudformation deploy \
    --stack-name "${ENV_NAME}-pipeline" \
    --template-file "${INFRA_DIR}/05-pipeline.yaml" \
    --parameter-overrides \
        EnvironmentName="${ENV_NAME}" \
        GitHubOwner="${GH_OWNER}" \
        GitHubRepo="${GH_REPO}" \
        CodeStarConnectionArn="${CONN_ARN}" \
    --capabilities CAPABILITY_NAMED_IAM \
    --region "${REGION}"

  echo "Done. Fetch the ALB URL with:"
  echo "aws cloudformation describe-stacks --stack-name ${ENV_NAME}-edge --query \"Stacks[0].Outputs[?OutputKey=='ALBDNSName'].OutputValue\" --output text --region ${REGION}"
fi
