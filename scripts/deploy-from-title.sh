#!/bin/bash
set -e

TITLE=$1
LAMBDA_NAME=$(echo "$TITLE" | cut -d':' -f2 | xargs)

echo "🚀 INICIANDO DESPLIEGUE"
echo "======================"

# 1. Buscar directorio lambda
LAMBDA_DIR=$(find lambdas/ -maxdepth 1 -type d -iname "*${LAMBDA_NAME}*" | head -1)
if [ -z "$LAMBDA_DIR" ]; then
  echo "❌ ERROR: No se encuentra directorio lambda"
  exit 1
fi
echo "✅ Directorio Lambda: $LAMBDA_DIR"

# 2. Detectar estructura
echo "🔍 Analizando estructura..."
if [ -f "$LAMBDA_DIR/src/lambda_function.py" ]; then
  echo "📁 Estructura detectada: Archivos en src/"
  STRUCTURE="src"
else
  echo "📁 Estructura detectada: Archivos en raíz"
  STRUCTURE="root"
fi

# 3. Buscar template
TEMPLATE_FILE=$(find infrastructure/ -maxdepth 1 -iname "*${LAMBDA_NAME}*.yml" | head -1)
if [ -z "$TEMPLATE_FILE" ]; then
  echo "❌ ERROR: No se encuentra template"
  exit 1
fi
echo "✅ Template: $TEMPLATE_FILE"

# 4. Probar construcción Docker
echo "🔨 Probando construcción Docker..."
if [ "$STRUCTURE" = "src" ]; then
  # Crear Dockerfile temporal para prueba
  cat > /tmp/Dockerfile.test << 'EOF'
FROM public.ecr.aws/lambda/python:3.12
RUN yum install -y gcc gcc-c++ make && yum clean all
COPY src/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY src/lambda_function.py ${LAMBDA_TASK_ROOT}
CMD ["lambda_function.handler"]
EOF
  
  cp /tmp/Dockerfile.test "$LAMBDA_DIR/Dockerfile"
fi

cd "$LAMBDA_DIR"
if docker build -t test-lambda .; then
  echo "✅ Docker build EXITOSO"
else
  echo "❌ Docker build FALLÓ"
  echo "💡 Sugerencia: Verifica que los archivos estén en el lugar correcto"
  ls -la "$LAMBDA_DIR/"
  [ -d "$LAMBDA_DIR/src" ] && ls -la "$LAMBDA_DIR/src/"
  exit 1
fi
cd - > /dev/null

# 5. Construir con SAM
echo "🏗️ Construyendo con SAM..."
export SAM_CLI_TELEMETRY=0
sam build \
  --template-file "$TEMPLATE_FILE" \
  --use-container

# 6. Desplegar
echo "☁️ Desplegando a AWS..."
sam deploy \
  --template-file .aws-sam/build/template.yaml \
  --stack-name "$LAMBDA_NAME" \
  --capabilities CAPABILITY_IAM CAPABILITY_AUTO_EXPAND \
  --resolve-image-repos \
  --no-confirm-changeset \
  --no-fail-on-empty-changeset

echo "🎉 ¡DESPLIEGUE COMPLETADO EXITOSAMENTE!"