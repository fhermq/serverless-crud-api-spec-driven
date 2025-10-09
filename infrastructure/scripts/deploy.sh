#!/bin/bash

# Deployment script for Serverless CRUD API
set -e

# Default values
STAGE="dev"
REGION="us-east-1"
STACK_NAME=""
GUIDED=false

# Parse command line arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    -s|--stage)
      STAGE="$2"
      shift 2
      ;;
    -r|--region)
      REGION="$2"
      shift 2
      ;;
    -n|--stack-name)
      STACK_NAME="$2"
      shift 2
      ;;
    -g|--guided)
      GUIDED=true
      shift
      ;;
    -h|--help)
      echo "Usage: $0 [OPTIONS]"
      echo "Options:"
      echo "  -s, --stage STAGE        Deployment stage (dev, staging, prod) [default: dev]"
      echo "  -r, --region REGION      AWS region [default: us-east-1]"
      echo "  -n, --stack-name NAME    CloudFormation stack name"
      echo "  -g, --guided             Run guided deployment"
      echo "  -h, --help               Show this help message"
      exit 0
      ;;
    *)
      echo "Unknown option $1"
      exit 1
      ;;
  esac
done

# Set default stack name if not provided
if [ -z "$STACK_NAME" ]; then
  STACK_NAME="serverless-crud-api-$STAGE"
fi

echo "🚀 Deploying Serverless CRUD API"
echo "Stage: $STAGE"
echo "Region: $REGION"
echo "Stack Name: $STACK_NAME"
echo ""

# Check if AWS CLI is configured
if ! aws sts get-caller-identity > /dev/null 2>&1; then
  echo "❌ AWS CLI is not configured or credentials are invalid"
  exit 1
fi

# Check if SAM CLI is installed
if ! command -v sam &> /dev/null; then
  echo "❌ SAM CLI is not installed. Please install it first."
  echo "   https://docs.aws.amazon.com/serverless-application-model/latest/developerguide/serverless-sam-cli-install.html"
  exit 1
fi

# Navigate to infrastructure directory
cd "$(dirname "$0")"

# Build Go functions
echo "🔨 Building Go functions..."
cd ../../functions/create-item
go mod tidy
GOOS=linux GOARCH=amd64 go build -o main main.go
cd ../delete-item
go mod tidy
GOOS=linux GOARCH=amd64 go build -o main main.go

# Install Node.js dependencies
echo "📦 Installing Node.js dependencies..."
cd ../get-item
npm install --production
cd ../update-item
npm install --production

# Return to infrastructure directory
cd ../../infrastructure

# Build SAM application
echo "🔨 Building SAM application..."
sam build --template-file template.yaml

# Deploy based on mode
if [ "$GUIDED" = true ]; then
  echo "🚀 Running guided deployment..."
  sam deploy --guided \
    --stack-name "$STACK_NAME" \
    --region "$REGION" \
    --capabilities CAPABILITY_IAM \
    --parameter-overrides "Stage=$STAGE"
else
  echo "🚀 Deploying to $STAGE environment..."
  sam deploy \
    --template-file .aws-sam/build/template.yaml \
    --stack-name "$STACK_NAME" \
    --region "$REGION" \
    --capabilities CAPABILITY_IAM \
    --parameter-overrides file://parameters/$STAGE.json \
    --no-confirm-changeset \
    --no-fail-on-empty-changeset
fi

# Get stack outputs
echo ""
echo "📋 Stack Outputs:"
aws cloudformation describe-stacks \
  --stack-name "$STACK_NAME" \
  --region "$REGION" \
  --query 'Stacks[0].Outputs[*].[OutputKey,OutputValue]' \
  --output table

echo ""
echo "✅ Deployment completed successfully!"
echo "Stack Name: $STACK_NAME"
echo "Region: $REGION"
echo "Stage: $STAGE"