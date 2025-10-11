#!/bin/bash

# Deploy All Stacks - Orchestrated deployment of the entire Serverless CRUD API
set -e

# Default values
STAGE="dev"
REGION="us-east-1"
PROJECT_NAME="serverless-crud-api"
SKIP_MONITORING=false

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
    --skip-monitoring)
      SKIP_MONITORING=true
      shift
      ;;
    -h|--help)
      echo "Usage: $0 [OPTIONS]"
      echo "Options:"
      echo "  -s, --stage STAGE        Deployment stage (dev, staging, prod) [default: dev]"
      echo "  -r, --region REGION      AWS region [default: us-east-1]"
      echo "  -p, --project-name NAME  Project name [default: serverless-crud-api]"
      echo "  --skip-monitoring        Skip monitoring stack deployment"
      echo "  -h, --help               Show this help message"
      exit 0
      ;;
    *)
      echo "Unknown option $1"
      exit 1
      ;;
  esac
done

echo "🚀 Deploying Complete Serverless CRUD API"
echo "Project: $PROJECT_NAME"
echo "Stage: $STAGE"
echo "Region: $REGION"
echo "Skip Monitoring: $SKIP_MONITORING"
echo ""

# Check if AWS CLI is configured
if ! aws sts get-caller-identity > /dev/null 2>&1; then
  echo "❌ AWS CLI is not configured or credentials are invalid"
  exit 1
fi

# Check if SAM CLI is installed
if ! command -v sam &> /dev/null; then
  echo "❌ SAM CLI is not installed. Please install it first."
  exit 1
fi

# Navigate to scripts directory
cd "$(dirname "$0")"

# Make scripts executable
chmod +x deploy-foundation.sh deploy-api.sh deploy-functions.sh deploy-monitoring.sh

echo "📋 Deployment Plan:"
echo "1. Foundation Stack (DynamoDB, IAM roles)"
echo "2. API and Functions Stack (API Gateway + Lambda functions)"
if [ "$SKIP_MONITORING" = false ]; then
  echo "3. Monitoring Stack (CloudWatch, alarms)"
fi
echo ""

# Step 1: Deploy Foundation Stack
echo "🏗️  Step 1/3: Deploying Foundation Stack..."
./deploy-foundation.sh --stage "$STAGE" --region "$REGION" --project-name "$PROJECT_NAME"
echo ""

# Step 2: Deploy API and Functions Stack
echo "🌐⚡ Step 2/3: Deploying API and Functions Stack..."
./deploy-api-and-functions.sh --stage "$STAGE" --region "$REGION" --project-name "$PROJECT_NAME"
echo ""

# Step 3: Deploy Monitoring Stack (optional)
if [ "$SKIP_MONITORING" = false ]; then
  echo "📊 Step 3/3: Deploying Monitoring Stack..."
  ./deploy-monitoring.sh --stage "$STAGE" --region "$REGION" --project-name "$PROJECT_NAME"
  echo ""
fi

# Get final API URL
API_STACK_NAME="$PROJECT_NAME-$STAGE-api"
API_URL=$(aws cloudformation describe-stacks \
  --stack-name "$API_STACK_NAME" \
  --region "$REGION" \
  --query 'Stacks[0].Outputs[?OutputKey==`ApiUrl`].OutputValue' \
  --output text)

echo ""
echo "🎉 Deployment Complete!"
echo "=================================="
echo "Project: $PROJECT_NAME"
echo "Stage: $STAGE"
echo "Region: $REGION"
echo ""
echo "📡 API Endpoint: $API_URL"
echo ""
echo "📋 Stack Names:"
echo "  Foundation: $PROJECT_NAME-$STAGE-foundation"
echo "  API and Functions: $PROJECT_NAME-$STAGE-api"
if [ "$SKIP_MONITORING" = false ]; then
  echo "  Monitoring: $PROJECT_NAME-$STAGE-monitoring"
fi
echo ""
echo "🧪 Test your API:"
echo "  curl -X GET $API_URL/items/test-id"
echo "  curl -X POST $API_URL/items -H 'Content-Type: application/json' -d '{\"name\":\"Test Item\",\"category\":\"electronics\",\"price\":29.99}'"
echo ""
echo "📊 CloudWatch Dashboard:"
if [ "$SKIP_MONITORING" = false ]; then
  echo "  https://$REGION.console.aws.amazon.com/cloudwatch/home?region=$REGION#dashboards:name=$PROJECT_NAME-$STAGE-api-dashboard"
fi
echo ""
echo "🗑️  To delete all stacks:"
echo "  aws cloudformation delete-stack --stack-name $PROJECT_NAME-$STAGE-monitoring --region $REGION"
echo "  aws cloudformation delete-stack --stack-name $PROJECT_NAME-$STAGE-api --region $REGION"
echo "  aws cloudformation delete-stack --stack-name $PROJECT_NAME-$STAGE-foundation --region $REGION"