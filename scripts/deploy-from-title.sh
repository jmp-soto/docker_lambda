#!/bin/bash
set -e

TITLE=$1

# Extract everything after "deploy:"
LAMBDA_NAMES=$(echo "$TITLE" | grep -oP 'deploy:\s*\K.*' || echo "")
if [ -z "$LAMBDA_NAMES" ]; then
  echo "❌ No lambda names found in title: $TITLE"
  exit 1
fi

# Remove spaces and split by comma
LAMBDA_NAMES=$(echo "$LAMBDA_NAMES" | tr -d ' ')
IFS=',' read -ra LAMBDA_ARRAY <<< "$LAMBDA_NAMES"

echo "📋 Deploying Lambdas: ${LAMBDA_ARRAY[*]}"
echo "Current directory: $(pwd)"

for LAMBDA_NAME in "${LAMBDA_ARRAY[@]}"; do
  echo ""
  echo "🚀 Processing Lambda: $LAMBDA_NAME"
  
  # Find template (case-insensitive)
  TEMPLATE_FILE=$(find infrastructure/ -iname "${LAMBDA_NAME}.yml" -type f | head -1)
  
  if [ -z "$TEMPLATE_FILE" ]; then
    echo "❌ Template not found for: $LAMBDA_NAME"
    echo "Available templates:"
    ls -la infrastructure/*.yml 2>/dev/null || echo "No templates found"
    exit 1
  fi
  
  echo "📄 Using template: $TEMPLATE_FILE"
  
  # Find Docker context directory (case-insensitive)
  DOCKER_DIR=$(find lambdas/ -maxdepth 1 -type d -iname "${LAMBDA_NAME}" | head -1)
  
  if [ -z "$DOCKER_DIR" ]; then
    echo "Docker context directory not found for: $LAMBDA_NAME"
    echo "Available lambda directories:"
    ls -la lambdas/ 2>/dev/null || echo "No lambda directories found"
    exit 1
  fi
  
  echo "✅ Found Docker context directory: $DOCKER_DIR"
  
  # Build with SAM
  echo "🔨 Building SAM application..."
  sam build \
    --template-file "$TEMPLATE_FILE" \
    --use-container
  
  # Deploy with SAM
  echo "☁️  Deploying to AWS..."
  sam deploy \
    --template-file .aws-sam/build/template.yaml \
    --stack-name "$LAMBDA_NAME" \
    --capabilities CAPABILITY_IAM CAPABILITY_AUTO_EXPAND \
    --resolve-image-repos \
    --no-confirm-changeset \
    --no-fail-on-empty-changeset
  
  echo "✅ Successfully deployed: $LAMBDA_NAME"
done

echo ""
echo "🎉 All lambdas deployed successfully!"