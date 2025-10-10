#!/bin/bash

# Setup local DynamoDB table for development
echo "🚀 Setting up local DynamoDB table..."

# Configuration
TABLE_NAME="serverless-crud-api-items"
DYNAMODB_ENDPOINT="http://localhost:8000"
AWS_REGION="us-east-1"

# Check if DynamoDB Local is running
if ! curl -s "$DYNAMODB_ENDPOINT" > /dev/null; then
    echo "❌ DynamoDB Local is not running. Please start it with: docker-compose up dynamodb-local"
    exit 1
fi

# Check if table already exists
if aws dynamodb describe-table \
    --table-name "$TABLE_NAME" \
    --endpoint-url "$DYNAMODB_ENDPOINT" \
    --region "$AWS_REGION" \
    --no-cli-pager > /dev/null 2>&1; then
    echo "⚠️  Table '$TABLE_NAME' already exists. Deleting and recreating..."
    aws dynamodb delete-table \
        --table-name "$TABLE_NAME" \
        --endpoint-url "$DYNAMODB_ENDPOINT" \
        --region "$AWS_REGION" \
        --no-cli-pager > /dev/null
    
    # Wait for table to be deleted
    echo "⏳ Waiting for table deletion..."
    sleep 3
fi

# Create the Items table
echo "📝 Creating Items table..."
aws dynamodb create-table \
    --table-name "$TABLE_NAME" \
    --attribute-definitions \
        AttributeName=id,AttributeType=S \
        AttributeName=category,AttributeType=S \
        AttributeName=createdAt,AttributeType=S \
    --key-schema \
        AttributeName=id,KeyType=HASH \
    --global-secondary-indexes \
        IndexName=CategoryIndex,KeySchema=[{AttributeName=category,KeyType=HASH},{AttributeName=createdAt,KeyType=RANGE}],Projection={ProjectionType=ALL},ProvisionedThroughput={ReadCapacityUnits=5,WriteCapacityUnits=5} \
    --provisioned-throughput \
        ReadCapacityUnits=5,WriteCapacityUnits=5 \
    --endpoint-url "$DYNAMODB_ENDPOINT" \
    --region "$AWS_REGION" \
    --no-cli-pager > /dev/null

if [ $? -eq 0 ]; then
    echo "✅ Table '$TABLE_NAME' created successfully!"
    
    # Wait for table to be active
    echo "⏳ Waiting for table to become active..."
    aws dynamodb wait table-exists \
        --table-name "$TABLE_NAME" \
        --endpoint-url "$DYNAMODB_ENDPOINT" \
        --region "$AWS_REGION"
    
    echo "🎉 Local DynamoDB setup complete!"
    echo ""
    echo "Table details:"
    aws dynamodb describe-table \
        --table-name "$TABLE_NAME" \
        --endpoint-url "$DYNAMODB_ENDPOINT" \
        --region "$AWS_REGION" \
        --no-cli-pager \
        --query 'Table.{TableName:TableName,Status:TableStatus,ItemCount:ItemCount,GlobalSecondaryIndexes:GlobalSecondaryIndexes[].{IndexName:IndexName,Status:IndexStatus}}'
else
    echo "❌ Failed to create table"
    exit 1
fi