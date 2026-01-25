#!/bin/bash
set -e

TITLE=$1
LAMBDA_NAME=$(echo "$TITLE" | cut -d':' -f2 | xargs)

# Convertir a minúsculas para Docker
LAMBDA_NAME_LOWER=$(echo "$LAMBDA_NAME" | tr '[:upper:]' '[:lower:]')

echo "INICIANDO DESPLIEGUE"
echo "======================"
echo "Lambda: $LAMBDA_NAME"
echo "Directorio actual: $(pwd)"
echo ""

# 1. LIMPIAR template de comentarios problemáticos
echo "🧹 Limpiando template YAML..."
TEMPLATE_FILE="infrastructure/${LAMBDA_NAME}.yml"
if [ ! -f "$TEMPLATE_FILE" ]; then
  TEMPLATE_FILE="infrastructure/${LAMBDA_NAME^}.yml"
fi

if [ ! -f "$TEMPLATE_FILE" ]; then
  TEMPLATE_FILE=$(find infrastructure/ -maxdepth 1 -iname "*${LAMBDA_NAME}*.yml" | head -1)
fi

if [ ! -f "$TEMPLATE_FILE" ]; then
  echo "❌ ERROR: No se encuentra template"
  exit 1
fi

# Crear copia limpia del template
CLEAN_TEMPLATE="/tmp/template-clean-$(date +%s).yml"
cp "$TEMPLATE_FILE" "$CLEAN_TEMPLATE"

# Eliminar comentarios en la línea de DockerContext
sed -i '/DockerContext:/s/#.*//' "$CLEAN_TEMPLATE"
sed -i '/DockerContext:/,/DockerTag:/{/^[[:space:]]*#/d}' "$CLEAN_TEMPLATE"
sed -i 's/DockerContext:.*#.*$/DockerContext: lambdas\/Lambda-da-ml-order-inicial-cl/' "$CLEAN_TEMPLATE"

echo "✅ Template limpio creado: $CLEAN_TEMPLATE"
echo "--- Contenido limpio ---"
cat "$CLEAN_TEMPLATE"
echo "--- Fin del template ---"

# 2. ENCONTRAR directorio lambda
echo "🔍 Buscando directorio lambda..."
LAMBDA_DIR="./lambdas/Lambda-da-ml-order-inicial-cl"

if [ ! -d "$LAMBDA_DIR" ]; then
  LAMBDA_DIR=$(find ./lambdas -maxdepth 1 -type d -iname "*$LAMBDA_NAME*" | head -1)
fi

if [ -z "$LAMBDA_DIR" ] || [ ! -d "$LAMBDA_DIR" ]; then
  echo "❌ ERROR: No se encuentra directorio"
  exit 1
fi

echo "✅ Directorio Lambda: $LAMBDA_DIR"

# 3. VERIFICAR archivos
echo "📁 Verificando archivos..."
if [ ! -f "$LAMBDA_DIR/src/lambda_function.py" ]; then
  echo "❌ ERROR: No se encuentra lambda_function.py en src/"
  exit 1
fi
echo "✅ lambda_function.py encontrado"

# 4. CREAR Dockerfile
echo "🐳 Configurando Dockerfile..."
cat > "$LAMBDA_DIR/Dockerfile" << 'EOF'
FROM public.ecr.aws/lambda/python:3.12
RUN microdnf install -y gcc gcc-c++ make && microdnf clean all
COPY src/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY src/lambda_function.py ${LAMBDA_TASK_ROOT}
CMD ["lambda_function.handler"]
EOF

echo "📝 Dockerfile creado"

# 5. ACTUALIZAR template con ruta CORRECTA
echo "🔄 Actualizando DockerContext en template..."
RELATIVE_PATH="lambdas/Lambda-da-ml-order-inicial-cl"
sed -i "s|DockerContext:.*|DockerContext: $RELATIVE_PATH|" "$CLEAN_TEMPLATE"

# 6. PROBAR construcción Docker
echo "🔨 Probando Docker build..."
cd "$LAMBDA_DIR"
if docker build -t "$LAMBDA_NAME_LOWER:test" .; then
  echo "✅ Docker build EXITOSO"
else
  echo "❌ Docker build FALLÓ"
  exit 1
fi
cd - > /dev/null

# 7. CONSTRUIR con SAM
echo "🏗️ Construyendo con SAM..."
export SAM_CLI_TELEMETRY=0

# Primero verificar que SAM puede parsear el template
echo "Validando template..."
sam validate --template-file "$CLEAN_TEMPLATE"

# Construir
sam build \
  --template-file "$CLEAN_TEMPLATE" \
  --use-container \
  --debug 2>&1 | tail -20

# 8. DESPLEGAR
echo "☁️ Desplegando a AWS..."
sam deploy \
  --template-file .aws-sam/build/template.yaml \
  --stack-name "$LAMBDA_NAME_LOWER" \
  --capabilities CAPABILITY_IAM CAPABILITY_AUTO_EXPAND \
  --resolve-image-repos \
  --no-confirm-changeset \
  --no-fail-on-empty-changeset \
  --parameter-overrides "Stage=prod"

echo "🎉 ¡DESPLIEGUE COMPLETADO EXITOSAMENTE!"