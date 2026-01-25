#!/bin/bash
set -e

TITLE=$1
LAMBDA_NAME=$(echo "$TITLE" | cut -d':' -f2 | xargs)

echo "🚀 INICIANDO DESPLIEGUE"
echo "======================"

# 1. VERIFICAR ESTRUCTURA
echo "📁 Verificando estructura del proyecto..."
if [ ! -d "lambdas" ]; then
  echo "❌ ERROR: No existe directorio 'lambdas'"
  exit 1
fi

# 2. BUSCAR TEMPLATE (case-insensitive)
TEMPLATE_FILE=$(find infrastructure/ -maxdepth 1 -iname "*${LAMBDA_NAME}*.yml" | head -1)
if [ -z "$TEMPLATE_FILE" ]; then
  echo "❌ ERROR: No se encuentra template para $LAMBDA_NAME"
  exit 1
fi
echo "✅ Template: $TEMPLATE_FILE"

# 3. BUSCAR DIRECTORIO LAMBDA (case-insensitive)
LAMBDA_DIR=$(find lambdas/ -maxdepth 1 -type d -iname "*${LAMBDA_NAME}*" | head -1)
if [ -z "$LAMBDA_DIR" ]; then
  echo "❌ ERROR: No se encuentra directorio lambda para $LAMBDA_NAME"
  exit 1
fi
echo "✅ Directorio Lambda: $LAMBDA_DIR"

# 4. VERIFICAR DOCKERFILE
if [ ! -f "$LAMBDA_DIR/Dockerfile" ]; then
  echo "❌ ERROR: No hay Dockerfile en $LAMBDA_DIR"
  exit 1
fi
echo "✅ Dockerfile encontrado"

# 5. PROBAR CONSTRUCCIÓN DOCKER MANUAL
echo "🔨 Probando construcción Docker manual..."
if docker build -t test-lambda "$LAMBDA_DIR"; then
  echo "✅ Docker build manual EXITOSO"
else
  echo "❌ Docker build manual FALLÓ"
  exit 1
fi

# 6. CONSTRUIR CON SAM (con debug)
echo "🏗️ Construyendo con SAM..."
export SAM_CLI_TELEMETRY=0  # Desactivar telemetría
sam build \
  --template-file "$TEMPLATE_FILE" \
  --use-container \
  --debug 2>&1 | grep -E "(Building|DockerContext|path|Error)" || true

# 7. DESPLEGAR
echo "☁️ Desplegando a AWS..."
sam deploy \
  --template-file .aws-sam/build/template.yaml \
  --stack-name "$LAMBDA_NAME" \
  --capabilities CAPABILITY_IAM CAPABILITY_AUTO_EXPAND \
  --resolve-image-repos \
  --no-confirm-changeset \
  --no-fail-on-empty-changeset

echo "🎉 ¡DESPLIEGUE COMPLETADO EXITOSAMENTE!"