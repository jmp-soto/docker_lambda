#!/bin/bash
set -e

TITLE=$1
LAMBDA_NAME=$(echo "$TITLE" | cut -d':' -f2 | xargs)
LAMBDA_NAME_LOWER=$(echo "$LAMBDA_NAME" | tr '[:upper:]' '[:lower:]')

echo "DESPLIEGUE: $LAMBDA_NAME"

# 1. RUTAS
REPO_ROOT="$(pwd)"
LAMBDAS_CONFIG="$REPO_ROOT/templates/lambdas.yml"

# 2. LEER CONFIGURACIÓN
if [ ! -f "$LAMBDAS_CONFIG" ]; then
  echo "$LAMBDAS_CONFIG no encontrado"
  exit 1
fi

LAMBDA_CONFIG=$(grep -A 2 "name: $LAMBDA_NAME" "$LAMBDAS_CONFIG")
LAMBDA_PATH=$(echo "$LAMBDA_CONFIG" | grep "path:" | cut -d':' -f2 | xargs)

if [ -z "$LAMBDA_PATH" ]; then
  echo "Lambda '$LAMBDA_NAME' no configurada"
  exit 1
fi

# 3. DIRECTORIO
LAMBDA_DIR="$REPO_ROOT/$LAMBDA_PATH"

if [ ! -d "$LAMBDA_DIR" ]; then
  echo "Directorio no existe: $LAMBDA_DIR"
  exit 1
fi

echo "$LAMBDA_DIR"

# 4. VERIFICAR ARCHIVOS ESENCIALES
TEMPLATE_FILE="$LAMBDA_DIR/template.yaml"
if [ ! -f "$TEMPLATE_FILE" ] && [ -f "$LAMBDA_DIR/template.yml" ]; then
  TEMPLATE_FILE="$LAMBDA_DIR/template.yml"
fi

if [ ! -f "$TEMPLATE_FILE" ]; then
  echo "Template no encontrado en $LAMBDA_DIR"
  exit 1
fi

if [ ! -f "$LAMBDA_DIR/Dockerfile" ]; then
  echo "Dockerfile no encontrado"
  exit 1
fi

# 5. DOCKER BUILD
cd "$LAMBDA_DIR"
docker build -t "$LAMBDA_NAME_LOWER:test" .
cd "$REPO_ROOT"

# 6. SAM BUILD
export SAM_CLI_TELEMETRY=0
rm -rf .aws-sam 2>/dev/null || true

cd "$LAMBDA_DIR"
sam build \
  --template-file "$(basename "$TEMPLATE_FILE")" \
  --build-dir "$REPO_ROOT/.aws-sam/build" \
  --use-container
cd "$REPO_ROOT"

# 7. SAM DEPLOY
sam deploy \
  --template-file "$REPO_ROOT/.aws-sam/build/template.yaml" \
  --stack-name "$LAMBDA_NAME_LOWER" \
  --s3-bucket "bucket-athena-nelson" \
  --capabilities CAPABILITY_IAM CAPABILITY_AUTO_EXPAND \
  --resolve-image-repos \
  --no-confirm-changeset \
  --no-fail-on-empty-changeset

echo "✅ $LAMBDA_NAME desplegado"