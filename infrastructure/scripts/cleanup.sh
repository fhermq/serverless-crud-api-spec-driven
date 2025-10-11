#!/bin/bash

# Cleanup Script - Delete all stacks in reverse order
set -e

# Default values
STAGE="dev"
REGION="us-east-1"
PROJECT_NAME="serverless-crud-api"
FORCE=false

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
    -f|--force)
      FORCE=true
      shift
      ;;
    -h|--help)
      echo "Usage: $0 [OPTIONS]"
      echo "Options:"
      echo "  -s, --stage STAGE        Deployment stage (dev, staging, prod) [default: dev]"
      echo "  -r, --region REGION      AWS region [default: us-east-1]"
      echo "  -p, --project-name NAME  Project name [default: serverless-crud-api]"
      echo "  -f, --force              Skip confirmation prompt"
      echo "  -h, --help               Show this help message"
      exit 0
      ;;
    *)
      echo "Unknown option $1"
      exit 1
      ;;
  esac
done

# Stack names
MONITORING_STACK="$PROJECT_NAME-$STAGE-monitoring"
API_STACK="$PROJECT_NAME-$STAGE-api"
FOUNDATION_STACK="$PROJECT_NAME-$STAGE-foundation"

echo "🗑️  Cleanup Serverless CRUD API Stacks"
echo "Project: $PROJECT_NAME"
echo "Stage: $STAGE"
echo "Region: $REGION"
echo ""
echo "⚠️  This will delete the following stacks:"
echo "  - $MONITORING_STACK"
echo "  - $API_STACK"
echo "  - $FOUNDATION_STACK"
echo ""

# Confirmation prompt
if [ "$FORCE" = false ]; then
  read -p "Are you sure you want to delete all stacks? (y/N): " -n 1 -r
  echo
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Cleanup cancelled."
    exit 0
  fi
fi

echo "🚀 Starting cleanup process..."
echo ""

# Function to delete stack if it exists
delete_stack_if_exists() {
  local stack_name=$1
  local description=$2
  
  if aws cloudformation describe-stacks --stack-name "$stack_name" --region "$REGION" > /dev/null 2>&1; then
    echo "🗑️  Deleting $description..."
    aws cloudformation delete-stack --stack-name "$stack_name" --region "$REGION"
    
    echo "⏳ Waiting for $description to be deleted..."
    aws cloudformation wait stack-delete-complete --stack-name "$stack_name" --region "$REGION"
    echo "✅ $description deleted successfully"
  else
    echo "ℹ️  $description does not exist, skipping..."
  fi
  echo ""
}

# Delete stacks in reverse dependency order
delete_stack_if_exists "$MONITORING_STACK" "Monitoring Stack"
delete_stack_if_exists "$API_STACK" "API and Functions Stack"
delete_stack_if_exists "$FOUNDATION_STACK" "Foundation Stack"

echo "🎉 Cleanup completed successfully!"
echo ""
echo "All stacks for $PROJECT_NAME-$STAGE have been deleted."