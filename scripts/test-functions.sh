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