#!/bin/bash
set -e

TITLE=$1
LAMBDA_NAME=$(echo "$TITLE" | cut -d':' -f2 | xargs)

# Try different casing variations
TEMPLATE_LOWER="infrastructure/${LAMBDA_NAME}.yml"
TEMPLATE_UPPER="infrastructure/${LAMBDA_NAME^}.yml"  # Capitalize first letter

# Check which file exists
if [ -f "$TEMPLATE_LOWER" ]; then
  TEMPLATE="$TEMPLATE_LOWER"
elif [ -f "$TEMPLATE_UPPER" ]; then
  TEMPLATE="$TEMPLATE_UPPER"
else
  echo "❌ Template not found. Tried:"
  echo "   - $TEMPLATE_LOWER"
  echo "   - $TEMPLATE_UPPER"
  exit 1
fi

echo "Deploying Lambda Image: $LAMBDA_NAME"
echo "📄 Using template: $TEMPLATE"

sam build \
  --template-file "$TEMPLATE"

sam deploy \
  --template-file .aws-sam/build/template.yaml \
  --stack-name "$LAMBDA_NAME" \
  --capabilities CAPABILITY_IAM \
  --resolve-image-repos \
  --no-confirm-changeset