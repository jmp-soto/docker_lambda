#!/bin/bash
set -e

TITLE=$1
LAMBDA_NAME=$(echo "$TITLE" | cut -d':' -f2 | xargs)
ENVIRONMENT=${2:-"dev"}

echo "========================================"
echo "DESPLIEGUE RAPIDO DESDE TITULO"
echo "Lambda: $LAMBDA_NAME"
echo "Entorno: $ENVIRONMENT"
echo "========================================"

REPO_ROOT="$(pwd)"

# ... (your existing case statement remains the same)

# ECR configuration
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
AWS_REGION="us-east-1"
ECR_REPO_NAME="$LAMBDA_NAME"
ECR_URI="$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$ECR_REPO_NAME"

echo "Login to ECR..."
aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com

# Check if ECR repository exists, create if not
if ! aws ecr describe-repositories --repository-names $ECR_REPO_NAME --region $AWS_REGION > /dev/null 2>&1; then
    echo "Creating ECR repository: $ECR_REPO_NAME"
    aws ecr create-repository --repository-name $ECR_REPO_NAME --region $AWS_REGION
fi

echo "Construyendo imagen Docker..."
cd "$LAMBDA_DIR"
docker build -t "$ECR_REPO_NAME:latest" .

echo "Tagging and pushing to ECR..."
docker tag "$ECR_REPO_NAME:latest" "$ECR_URI:latest"
docker push "$ECR_URI:latest"
cd "$REPO_ROOT"

echo "Desplegando CloudFormation stack..."

aws cloudformation deploy \
  --template-file "$TEMPLATE_FILE" \
  --stack-name "$STACK_NAME" \
  --region us-east-1 \
  --capabilities CAPABILITY_NAMED_IAM \
  --no-fail-on-empty-changeset \
  --parameter-overrides \
    Environment="$ENVIRONMENT" \
    LambdaName="$LAMBDA_NAME" \
    ImageUri="$ECR_URI:latest" \
  --tags \
    Environment="$ENVIRONMENT" \
    Project="ml-order-system" \
    ManagedBy="github-actions"

echo "$LAMBDA_NAME desplegado exitosamente"
echo "   Stack: $STACK_NAME"
echo "   Environment: $ENVIRONMENT"
echo "   Image URI: $ECR_URI:latest"