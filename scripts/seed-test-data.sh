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