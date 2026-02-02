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

STACK_NAME="$LAMBDA_NAME"

if [ ! -d "$LAMBDA_DIR" ]; then
  echo "ERROR: Directorio no encontrado: $LAMBDA_DIR"
  exit 1
fi

if [ ! -f "$TEMPLATE_FILE" ]; then
  echo "ERROR: Template no encontrado: $TEMPLATE_FILE"
  exit 1
fi

echo "Directorio: $LAMBDA_DIR"
echo "Template: $TEMPLATE_FILE"
echo "Stack: $STACK_NAME"
echo "Environment: $ENVIRONMENT"

echo "Construyendo imagen Docker..."
cd "$LAMBDA_DIR"
docker build -t "$LAMBDA_NAME:latest" .
cd "$REPO_ROOT"

echo "Docker image construida"

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
  --tags \
    Environment="$ENVIRONMENT" \
    Project="ml-order-system" \
    ManagedBy="github-actions"

echo "$LAMBDA_NAME desplegado exitosamente"
echo "   Stack: $STACK_NAME"
echo "   Environment: $ENVIRONMENT"