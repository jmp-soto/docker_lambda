#!/bin/bash
set -e

TITLE=$1
LAMBDA_NAME=$(echo "$TITLE" | cut -d':' -f2 | xargs)
LAMBDA_NAME_LOWER=$(echo "$LAMBDA_NAME" | tr '[:upper:]' '[:lower:]')

echo "🚀 INICIANDO DESPLIEGUE - VERSIÓN CORREGIDA"
echo "=========================================="

# 1. VERIFICACIONES PREVIAS CRÍTICAS
echo "🔍 VERIFICACIONES INICIALES"
echo "Directorio actual: $(pwd)"

# Verificar estructura del proyecto
if [ ! -d "lambdas" ]; then
  echo "❌ ERROR CRÍTICO: No existe directorio 'lambdas'"
  exit 1
fi

# Buscar directorio lambda (case-insensitive)
LAMBDA_DIR=$(find . -type d -path "*/lambdas/*" -iname "*$LAMBDA_NAME*" | head -1)
if [ -z "$LAMBDA_DIR" ]; then
  LAMBDA_DIR="lambdas/$LAMBDA_NAME"
fi

if [ ! -d "$LAMBDA_DIR" ]; then
  echo "❌ ERROR: Directorio Lambda no encontrado: $LAMBDA_DIR"
  echo "Directorios disponibles en lambdas/:"
  ls -la lambdas/ 2>/dev/null || echo "No hay directorios"
  exit 1
fi

echo "✅ Directorio Lambda: $LAMBDA_DIR (existe: $(ls -d "$LAMBDA_DIR" 2>/dev/null && echo "SÍ" || echo "NO"))"

# Verificar estructura interna
if [ ! -f "$LAMBDA_DIR/src/lambda_function.py" ]; then
  echo "❌ ERROR: No se encuentra $LAMBDA_DIR/src/lambda_function.py"
  exit 1
fi
echo "✅ lambda_function.py encontrado"

# 2. CREAR TEMPLATE ABSOLUTAMENTE CORRECTO
echo "📄 CREANDO TEMPLATE 100% CORRECTO"

# Crear template SIMPLE y CORRECTO
CORRECT_TEMPLATE="/tmp/template-correct-$(date +%s).yml"

cat > "$CORRECT_TEMPLATE" << EOF
AWSTemplateFormatVersion: '2010-09-09'
Transform: AWS::Serverless-2016-10-31

Resources:
  LambdaDaMlOrderInicialCl:
    Type: AWS::Serverless::Function
    Properties:
      FunctionName: $LAMBDA_NAME_LOWER
      PackageType: Image
      Timeout: 60
      MemorySize: 2048
    Metadata:
      Dockerfile: Dockerfile
      DockerContext: $LAMBDA_DIR
      DockerTag: latest
EOF

echo "✅ Template creado: $CORRECT_TEMPLATE"
echo "--- CONTENIDO DEL TEMPLATE ---"
cat "$CORRECT_TEMPLATE"
echo "--- FIN DEL TEMPLATE ---"

# 3. CREAR Dockerfile CORRECTO
echo "🐳 CREANDO DOCKERFILE"

DOCKERFILE_CONTENT="FROM public.ecr.aws/lambda/python:3.12
RUN microdnf install -y gcc gcc-c++ make && microdnf clean all
COPY src/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY src/lambda_function.py \${LAMBDA_TASK_ROOT}
CMD [\"lambda_function.handler\"]"

echo "$DOCKERFILE_CONTENT" > "$LAMBDA_DIR/Dockerfile"
echo "✅ Dockerfile creado en $LAMBDA_DIR/Dockerfile"

# 4. PROBAR CONSTRUCCIÓN DOCKER MANUALMENTE (IMPORTANTE)
echo "🔨 PROBANDO CONSTRUCCIÓN DOCKER MANUAL"

cd "$LAMBDA_DIR"
echo "Entrando a: $(pwd)"
echo "Contenido:"
ls -la
echo ""
echo "Contenido de src/:"
ls -la src/

# Construir con Docker directamente
DOCKER_BUILD_CMD="docker build -t $LAMBDA_NAME_LOWER:test ."
echo "Ejecutando: $DOCKER_BUILD_CMD"

if $DOCKER_BUILD_CMD; then
  echo "✅ DOCKER BUILD MANUAL EXITOSO"
else
  echo "❌ DOCKER BUILD MANUAL FALLÓ"
  echo "Último error Docker:"
  docker build -t "$LAMBDA_NAME_LOWER:test" . 2>&1 | tail -30
  exit 1
fi

cd - > /dev/null

# 5. CONSTRUIR CON SAM (MODO DEBUG)
echo "🏗️ CONSTRUYENDO CON SAM - MODO DEBUG"

export SAM_CLI_TELEMETRY=0

# Primero limpiar builds anteriores
rm -rf .aws-sam 2>/dev/null || true

# Construir con máximo debug
echo "Ejecutando sam build con debug..."
sam build \
  --template-file "$CORRECT_TEMPLATE" \
  --use-container \
  --debug 2>&1 | tee /tmp/sam-build.log

# Verificar si se creó template.yaml
if [ ! -f ".aws-sam/build/template.yaml" ]; then
  echo "❌ ERROR: SAM no generó template.yaml"
  echo "Logs de SAM:"
  tail -50 /tmp/sam-build.log
  echo ""
  echo "Intentando sin --use-container..."
  sam build --template-file "$CORRECT_TEMPLATE" 2>&1 | tail -30
  exit 1
fi

echo "✅ SAM BUILD EXITOSO"
echo "Template generado en: .aws-sam/build/template.yaml"

# 6. DESPLEGAR
echo "☁️ DESPLEGANDO A AWS"

sam deploy \
  --template-file .aws-sam/build/template.yaml \
  --stack-name "$LAMBDA_NAME_LOWER" \
  --capabilities CAPABILITY_IAM CAPABILITY_AUTO_EXPAND \
  --resolve-image-repos \
  --no-confirm-changeset \
  --no-fail-on-empty-changeset \
  --parameter-overrides "Stage=prod"

echo "🎉 ¡DESPLIEGUE COMPLETADO EXITOSAMENTE!"