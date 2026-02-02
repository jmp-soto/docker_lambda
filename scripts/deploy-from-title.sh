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

case "$LAMBDA_NAME" in
  lambda-da-ml-order-inicial-back-office)
    LAMBDA_DIR="lambdas/Lambda-da-ml-order-inicial-back-office"
    TEMPLATE_FILE="infrastructure/Lambda-da-ml-order-inicial-back-office.yml"
    ;;
  lambda-da-ml-order-inicial-cl)
    LAMBDA_DIR="lambdas/Lambda-da-ml-order-inicial-cl" 
    TEMPLATE_FILE="infrastructure/Lambda-da-ml-order-inicial-cl.yml"
    ;;
  *)
    echo "ERROR: Lambda no reconocida: $LAMBDA_NAME"
    echo "Lambdas validas:"
    echo "  - lambda-da-ml-order-inicial-back-office"
    echo "  - lambda-da-ml-order-inicial-cl"
    exit 1
    ;;
esac

STACK_NAME="$LAMBDA_NAME"  # ✅ Add environment to stack name to avoid conflicts

if [ ! -d "$LAMBDA_DIR" ]; then
  echo "ERROR: Directorio no encontrado: $LAMBDA_DIR"
  echo "Directorios disponibles en lambdas/:"
  ls -la lambdas/
  exit 1
fi

if [ ! -f "$TEMPLATE_FILE" ]; then
  echo "ERROR: Template no encontrado: $TEMPLATE_FILE"
  echo "Templates disponibles en infrastructure/:"
  ls -la infrastructure/
  exit 1
fi

# Check if Dockerfile exists
if [ ! -f "$LAMBDA_DIR/Dockerfile" ]; then
  echo "ERROR: Dockerfile no encontrado en: $LAMBDA_DIR/"
  echo "Archivos en $LAMBDA_DIR/:"
  ls -la "$LAMBDA_DIR/"
  exit 1
fi

echo "Directorio Lambda: $LAMBDA_DIR"
echo "Template: $TEMPLATE_FILE"
echo "Stack: $STACK_NAME"
echo "Environment: $ENVIRONMENT"
echo "Dockerfile encontrado: Sí"

# ECR configuration
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
AWS_REGION="us-east-1"
ECR_REPO_NAME="$LAMBDA_NAME"
ECR_URI="$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$ECR_REPO_NAME"

echo "Login a ECR..."
aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com

# Check if ECR repository exists, create if not
echo "Verificando repositorio ECR..."
if ! aws ecr describe-repositories --repository-names $ECR_REPO_NAME --region $AWS_REGION > /dev/null 2>&1; then
    echo "Creando repositorio ECR: $ECR_REPO_NAME"
    aws ecr create-repository --repository-name $ECR_REPO_NAME --region $AWS_REGION --image-scanning-configuration scanOnPush=true --image-tag-mutability MUTABLE
fi

echo "Construyendo imagen Docker desde: $LAMBDA_DIR"
cd "$LAMBDA_DIR"
docker build -t "$ECR_REPO_NAME:latest" .

echo "Tagging y pushing a ECR..."
docker tag "$ECR_REPO_NAME:latest" "$ECR_URI:latest"
docker push "$ECR_URI:latest"
cd "$REPO_ROOT"

echo "Desplegando CloudFormation stack..."

aws cloudformation deploy \
  --template-file "$TEMPLATE_FILE" \
  --stack-name "$STACK_NAME" \
  --region $AWS_REGION \
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

echo "========================================"
echo "$LAMBDA_NAME desplegado exitosamente!"
echo "   Stack: $STACK_NAME"
echo "   Environment: $ENVIRONMENT"
echo "   Image URI: $ECR_URI:latest"
echo "========================================"