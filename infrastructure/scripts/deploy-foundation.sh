#!/bin/bash

# Deploy Foundation Stack - DynamoDB and IAM roles
set -e

# Default values
STAGE="dev"
REGION="us-east-1"
PROJECT_NAME="serverless-crud-api"

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
    -p|--project-name)
      PROJECT_NAME="$2"
      shift 2
      ;;
    -h|--help)
      echo "Usage: $0 [OPTIONS]"
      echo "Options:"
      echo "  -s, --stage STAGE        Deployment stage (dev, staging, prod) [default: dev]"
      echo "  -r, --region REGION      AWS region [default: us-east-1]"
      echo "  -p, --project-name NAME  Project name [default: serverless-crud-api]"
      echo "  -h, --help               Show this help message"
      exit 0
      ;;
    *)
      echo "Unknown option $1"
      exit 1
      ;;
  esac
done

STACK_NAME="$PROJECT_NAME-$STAGE-foundation"

echo "🏗️  Deploying Foundation Stack"
echo "Stack Name: $STACK_NAME"
echo "Stage: $STAGE"
echo "Region: $REGION"
echo "Project: $PROJECT_NAME"
echo ""

# Check if AWS CLI is configured
if ! aws sts get-caller-identity > /dev/null 2>&1; then
  echo "❌ AWS CLI is not configured or credentials are invalid"
  exit 1
fi

# Navigate to infrastructure directory
cd "$(dirname "$0")/.."

# Build and deploy foundation stack
echo "🔨 Building Foundation stack..."
sam build --template-file stacks/01-foundation.yaml

echo "🚀 Deploying Foundation stack..."
sam deploy \
  --template-file .aws-sam/build/template.yaml \
  --stack-name "$STACK_NAME" \
  --region "$REGION" \
  --capabilities CAPABILITY_NAMED_IAM \
  --parameter-overrides \
    "Stage=$STAGE" \
    "ProjectName=$PROJECT_NAME" \
  --no-confirm-changeset \
  --no-fail-on-empty-changeset \
  --tags \
    Project="$PROJECT_NAME" \
    Stage="$STAGE" \
    Component="Foundation"

# Get stack outputs
echo ""
echo "📋 Foundation Stack Outputs:"
aws cloudformation describe-stacks \
  --stack-name "$STACK_NAME" \
  --region "$REGION" \
  --query 'Stacks[0].Outputs[*].[OutputKey,OutputValue]' \
  --output table

echo ""
echo "✅ Foundation stack deployed successfully!"
echo "Stack Name: $STACK_NAME"