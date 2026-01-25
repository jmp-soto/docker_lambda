#!/bin/bash
set -e

TITLE=$1
LAMBDA_NAME=$(echo "$TITLE" | cut -d':' -f2 | xargs)

echo "🚀 INICIANDO DESPLIEGUE"
echo "======================"
echo "Lambda: $LAMBDA_NAME"
echo "Directorio actual: $(pwd)"
echo ""

# 1. ENCONTRAR el directorio lambda (insensible a mayúsculas/minúsculas)
echo "🔍 Buscando directorio lambda..."
LAMBDA_DIR=$(find . -type d -path "*/$LAMBDA_NAME" -o -type d -iname "*$LAMBDA_NAME*" | head -1)

if [ -z "$LAMBDA_DIR" ]; then
  echo "⚠️ Intentando búsqueda alternativa..."
  # Buscar en directorios comunes
  if [ -d "lambdas/$LAMBDA_NAME" ]; then
    LAMBDA_DIR="lambdas/$LAMBDA_NAME"
  elif [ -d "lambdas/${LAMBDA_NAME^}" ]; then
    LAMBDA_DIR="lambdas/${LAMBDA_NAME^}"
  elif [ -d "$LAMBDA_NAME" ]; then
    LAMBDA_DIR="$LAMBDA_NAME"
  else
    echo "❌ ERROR: No se encuentra directorio para $LAMBDA_NAME"
    echo "Directorios disponibles:"
    find . -type d -maxdepth 2 | grep -i lambda || echo "No hay directorios lambda"
    exit 1
  fi
fi

echo "✅ Directorio Lambda encontrado: $LAMBDA_DIR"

# 2. VERIFICAR estructura interna
echo "📁 Analizando estructura interna..."
if [ -f "$LAMBDA_DIR/src/lambda_function.py" ]; then
  echo "📁 Estructura: Archivos en src/"
  HAS_SRC=1
elif [ -f "$LAMBDA_DIR/lambda_function.py" ]; then
  echo "📁 Estructura: Archivos en raíz"
  HAS_SRC=0
else
  echo "❌ ERROR: No se encuentra lambda_function.py"
  ls -la "$LAMBDA_DIR/"
  [ -d "$LAMBDA_DIR/src" ] && ls -la "$LAMBDA_DIR/src/"
  exit 1
fi

# 3. BUSCAR template
echo "📄 Buscando template..."
TEMPLATE_FILE=$(find infrastructure/ -maxdepth 1 -iname "*$LAMBDA_NAME*.yml" | head -1)

if [ -z "$TEMPLATE_FILE" ]; then
  echo "⚠️ Template no encontrado, buscando alternativas..."
  TEMPLATE_FILE=$(find . -name "*.yml" -type f | grep -i "$LAMBDA_NAME" | head -1)
fi

if [ -z "$TEMPLATE_FILE" ]; then
  echo "❌ ERROR: No se encuentra template para $LAMBDA_NAME"
  echo "Archivos YAML disponibles:"
  find . -name "*.yml" -type f | head -10
  exit 1
fi

echo "✅ Template: $TEMPLATE_FILE"

# 4. CREAR Dockerfile CORRECTO dinámicamente
echo "🐳 Creando Dockerfile optimizado..."
if [ $HAS_SRC -eq 1 ]; then
  cat > "$LAMBDA_DIR/Dockerfile" << 'EOF'
FROM public.ecr.aws/lambda/python:3.12

# Amazon Linux 2023 usa microdnf
RUN microdnf install -y gcc gcc-c++ make && microdnf clean all

# Copiar e instalar dependencias
COPY src/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copiar código
COPY src/lambda_function.py ${LAMBDA_TASK_ROOT}

# Handler
CMD ["lambda_function.handler"]
EOF
else
  cat > "$LAMBDA_DIR/Dockerfile" << 'EOF'
FROM public.ecr.aws/lambda/python:3.12

# Amazon Linux 2023 usa microdnf
RUN microdnf install -y gcc gcc-c++ make && microdnf clean all

# Copiar e instalar dependencias
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copiar código
COPY lambda_function.py ${LAMBDA_TASK_ROOT}

# Handler
CMD ["lambda_function.handler"]
EOF
fi

echo "📝 Dockerfile creado:"
cat "$LAMBDA_DIR/Dockerfile"
echo ""

# 5. PROBAR construcción Docker
echo "🔨 Probando construcción Docker..."
cd "$LAMBDA_DIR"
if docker build -t "$LAMBDA_NAME:latest" .; then
  echo "✅ Docker build EXITOSO"
else
  echo "❌ Docker build FALLÓ"
  echo "Contenido del directorio:"
  ls -la
  [ -d "src" ] && echo "Contenido de src/:" && ls -la src/
  exit 1
fi
cd - > /dev/null

# 6. ACTUALIZAR template YAML si es necesario
echo "🔄 Actualizando template con ruta correcta..."
# Obtener ruta relativa desde el directorio del template
TEMPLATE_DIR=$(dirname "$TEMPLATE_FILE")
RELATIVE_PATH=$(realpath --relative-to="$TEMPLATE_DIR" "$LAMBDA_DIR")

# Actualizar DockerContext en el template temporalmente
sed -i "s|DockerContext:.*|DockerContext: $RELATIVE_PATH|" "$TEMPLATE_FILE"
echo "📌 DockerContext actualizado a: $RELATIVE_PATH"

# 7. CONSTRUIR con SAM
echo "🏗️ Construyendo con SAM..."
export SAM_CLI_TELEMETRY=0
sam build \
  --template-file "$TEMPLATE_FILE" \
  --use-container \
  --debug 2>&1 | grep -E "(Building|Success|Error)" || true

# 8. DESPLEGAR
echo "☁️ Desplegando a AWS..."
sam deploy \
  --template-file .aws-sam/build/template.yaml \
  --stack-name "$LAMBDA_NAME" \
  --capabilities CAPABILITY_IAM CAPABILITY_AUTO_EXPAND \
  --resolve-image-repos \
  --no-confirm-changeset \
  --no-fail-on-empty-changeset

echo "🎉 ¡DESPLIEGUE COMPLETADO EXITOSAMENTE!"