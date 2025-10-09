#!/bin/bash

echo "🚀 Setting up Serverless CRUD API development environment..."

# Wait for DynamoDB Local to be ready
echo "⏳ Waiting for DynamoDB Local to start..."
while ! curl -s http://dynamodb-local:8000 > /dev/null; do
  sleep 2
done
echo "✅ DynamoDB Local is ready"

# Create DynamoDB table for local development
echo "📊 Creating local DynamoDB table..."
aws dynamodb create-table \
  --endpoint-url http://dynamodb-local:8000 \
  --table-name serverless-crud-api-dev-items \
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
  --region us-east-1 \
  || echo "Table may already exist"

# Install Node.js dependencies for all functions
echo "📦 Installing Node.js dependencies..."
cd /workspace/functions/get-item && npm install
cd /workspace/functions/update-item && npm install

# Download Go dependencies
echo "🐹 Downloading Go dependencies..."
cd /workspace/functions/create-item && go mod download
cd /workspace/functions/delete-item && go mod download

# Create local testing scripts
echo "📝 Creating local testing scripts..."
mkdir -p /workspace/scripts

# Create test data script
cat > /workspace/scripts/seed-test-data.sh << 'EOF'
#!/bin/bash

echo "🌱 Seeding test data..."

# Test items to create
TEST_ITEMS='[
  {"name":"Laptop","description":"High-performance laptop","category":"electronics","price":999.99},
  {"name":"T-Shirt","description":"Cotton t-shirt","category":"clothing","price":19.99},
  {"name":"Book","description":"Programming book","category":"books","price":39.99}
]'

# Create test items
echo "$TEST_ITEMS" | jq -c '.[]' | while read item; do
  echo "Creating item: $item"
  curl -X POST \
    -H "Content-Type: application/json" \
    -d "$item" \
    http://localhost:3000/items
  echo ""
done

echo "✅ Test data seeded"
EOF

chmod +x /workspace/scripts/seed-test-data.sh

# Create function testing script
cat > /workspace/scripts/test-functions.sh << 'EOF'
#!/bin/bash

echo "🧪 Testing Lambda functions locally..."

# Test Create Item Function (Go)
echo "Testing Create Item Function..."
sam local invoke CreateItemFunction \
  --event events/create-item-event.json \
  --template infrastructure/template.yaml

# Test Get Item Function (Node.js)
echo "Testing Get Item Function..."
sam local invoke GetItemFunction \
  --event events/get-item-event.json \
  --template infrastructure/template.yaml

# Test Update Item Function (Node.js)
echo "Testing Update Item Function..."
sam local invoke UpdateItemFunction \
  --event events/update-item-event.json \
  --template infrastructure/template.yaml

# Test Delete Item Function (Go)
echo "Testing Delete Item Function..."
sam local invoke DeleteItemFunction \
  --event events/delete-item-event.json \
  --template infrastructure/template.yaml

echo "✅ Function testing completed"
EOF

chmod +x /workspace/scripts/test-functions.sh

# Create local API start script
cat > /workspace/scripts/start-local-api.sh << 'EOF'
#!/bin/bash

echo "🚀 Starting local API with SAM..."

# Build the SAM application
cd /workspace/infrastructure
sam build --template-file template.yaml

# Start local API
sam local start-api \
  --host 0.0.0.0 \
  --port 3000 \
  --docker-network serverless-crud-api_serverless-network \
  --parameter-overrides \
    "ParameterKey=Stage,ParameterValue=dev" \
    "ParameterKey=TableName,ParameterValue=serverless-crud-api-dev-items"
EOF

chmod +x /workspace/scripts/start-local-api.sh

echo "✅ Development environment setup completed!"
echo ""
echo "🎯 Quick start commands:"
echo "  - Start local API: ./scripts/start-local-api.sh"
echo "  - Test functions: ./scripts/test-functions.sh"
echo "  - Seed test data: ./scripts/seed-test-data.sh"
echo "  - DynamoDB Admin: http://localhost:8001"
echo "  - LocalStack: http://localhost:4566"
echo ""