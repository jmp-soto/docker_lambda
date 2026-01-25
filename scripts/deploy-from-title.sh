#!/bin/bash
set -e

TITLE=$1
LAMBDA_NAME=$(echo "$TITLE" | cut -d':' -f2 | xargs)
LAMBDA_NAME_LOWER=$(echo "$LAMBDA_NAME" | tr '[:upper:]' '[:lower:]')

echo "🚀 INICIANDO DESPLIEGUE - VERSIÓN CORREGIDA"
echo "=========================================="
echo "Directorio actual: $(pwd)"
echo "Lambda: $LAMBDA_NAME"

# 1. DEFINIR RUTAS ABSOLUTAS
REPO_ROOT="$(pwd)"
LAMBDA_DIR="$REPO_ROOT/lambdas/$LAMBDA_NAME"

# Si no existe con mayúscula, buscar
if [ ! -d "$LAMBDA_DIR" ]; then
  LAMBDA_DIR=$(find "$REPO_ROOT/lambdas" -maxdepth 1 -type d -iname "*$LAMBDA_NAME*" | head -1)
fi

if [ ! -d "$LAMBDA_DIR" ]; then
  echo "❌ ERROR: Directorio no encontrado: $LAMBDA_DIR"
  exit 1
fi

echo "✅ Directorio Lambda: $LAMBDA_DIR"

# 2. VERIFICAR ESTRUCTURA
if [ ! -f "$LAMBDA_DIR/src/lambda_function.py" ]; then
  echo "❌ ERROR: No se encuentra $LAMBDA_DIR/src/lambda_function.py"
  exit 1
fi
echo "✅ lambda_function.py encontrado"

# 3. CREAR TEMPLATE CON RUTA ABSOLUTA
echo "📄 CREANDO TEMPLATE CON RUTA ABSOLUTA"

cat > "$REPO_ROOT/template-sam.yml" << EOF
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

echo "✅ Template creado en: $REPO_ROOT/template-sam.yml"
echo "--- CONTENIDO ---"
cat "$REPO_ROOT/template-sam.yml"
echo "--- FIN ---"

# 4. CREAR DOCKERFILE
echo "🐳 CREANDO DOCKERFILE"

cat > "$LAMBDA_DIR/Dockerfile" << 'EOF'
FROM public.ecr.aws/lambda/python:3.12
RUN microdnf install -y gcc gcc-c++ make && microdnf clean all
COPY src/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY src/lambda_function.py ${LAMBDA_TASK_ROOT}
CMD ["lambda_function.handler"]
EOF

echo "✅ Dockerfile creado"

# 5. PROBAR DOCKER BUILD
echo "🔨 PROBANDO DOCKER BUILD"

cd "$LAMBDA_DIR"
if docker build -t "$LAMBDA_NAME_LOWER:test" .; then
  echo "✅ DOCKER BUILD EXITOSO"
else
  echo "❌ DOCKER BUILD FALLÓ"
  exit 1
fi
cd "$REPO_ROOT"

# 6. CONSTRUIR CON SAM DESDE EL DIRECTORIO CORRECTO
echo "🏗️ CONSTRUYENDO CON SAM"

export SAM_CLI_TELEMETRY=0

# Limpiar builds anteriores
rm -rf .aws-sam 2>/dev/null || true

echo "Ejecutando sam build desde $REPO_ROOT..."
sam build \
  --template-file "$REPO_ROOT/template-sam.yml" \
  --build-dir "$REPO_ROOT/.aws-sam/build" \
  --use-container

if [ -f "$REPO_ROOT/.aws-sam/build/template.yaml" ]; then
  echo "✅ SAM BUILD EXITOSO"
else
  echo "❌ SAM BUILD FALLÓ - intentando sin --use-container"
  sam build \
    --template-file "$REPO_ROOT/template-sam.yml" \
    --build-dir "$REPO_ROOT/.aws-sam/build"
fi

echo "☁️ DESPLEGANDO A AWS"

sam deploy \
  --template-file "$REPO_ROOT/.aws-sam/build/template.yaml" \
  --stack-name "$LAMBDA_NAME_LOWER" \
  --s3-bucket "bucket-athena-nelson" \
  --capabilities CAPABILITY_IAM CAPABILITY_AUTO_EXPAND \
  --resolve-image-repos \
  --no-confirm-changeset \
  --no-fail-on-empty-changeset

echo "¡DESPLIEGUE COMPLETADO EXITOSAMENTE!"