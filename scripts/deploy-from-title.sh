#!/bin/bash
set -e

TITLE=$1
LAMBDA_NAME=$(echo "$TITLE" | cut -d':' -f2 | xargs)  # Added xargs to trim whitespace

TEMPLATE="infrastructure/${LAMBDA_NAME}.yml"

echo "Current directory: $(pwd)"
echo " Deploying Lambda Image: $LAMBDA_NAME"
echo "Using template: $TEMPLATE"
echo "Template exists: $(if [ -f "$TEMPLATE" ]; then echo "YES"; else echo "NO"; fi)"

ls -la infrastructure/  # Debug: list infrastructure directory

sam build \
  --template-file "$TEMPLATE"

sam deploy \
  --template-file .aws-sam/build/template.yaml \
  --stack-name "$LAMBDA_NAME" \
  --capabilities CAPABILITY_IAM \
  --resolve-image-repos \
  --no-confirm-changeset