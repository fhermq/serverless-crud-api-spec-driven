#!/bin/bash

echo "🚀 Starting local API with SAM..."

# Build the SAM application
cd infrastructure
sam build --template-file template.yaml

# Start local API
sam local start-api \
  --host 0.0.0.0 \
  --port 3000 \
  --docker-network serverless-crud-api_serverless-network \
  --parameter-overrides \
    "ParameterKey=Stage,ParameterValue=dev" \
    "ParameterKey=TableName,ParameterValue=serverless-crud-api-dev-items"