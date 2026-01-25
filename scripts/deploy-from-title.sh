#!/bin/bash
set -e

TITLE=$1
LAMBDA_NAME=$(echo "$TITLE" | cut -d':' -f2)

TEMPLATE="infrastructure/${LAMBDA_NAME}.yml"

echo "Deploying Lambda Image: $LAMBDA_NAME"

sam build \
  --template-file $TEMPLATE

sam deploy \
  --template-file .aws-sam/build/template.yaml \
  --stack-name $LAMBDA_NAME \
  --capabilities CAPABILITY_IAM \
  --resolve-image-repos \
  --no-confirm-changeset
