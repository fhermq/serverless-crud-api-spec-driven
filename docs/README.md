# API Documentation

## OpenAPI Specification

The complete API specification is available in `api-spec.yaml` (OpenAPI 3.0 format).

### Interactive Documentation
```bash
# Install swagger-ui-serve globally
npm install -g swagger-ui-serve

# Serve interactive documentation
swagger-ui-serve docs/api-spec.yaml

# Open http://localhost:3000 to view docs
```

### Import to Postman
Import `docs/api-spec.yaml` directly into Postman for testing.

## Authentication

All endpoints require an API key in the `X-API-Key` header:

```bash
curl -H "X-API-Key: your-api-key-here" https://api-url/items/123
```

Get your API key:
```bash
./infrastructure/scripts/get-api-key.sh dev
```

## Endpoints

### Create Item
```bash
POST /items
Content-Type: application/json

{
  "name": "Test Item",
  "category": "electronics", 
  "price": 29.99
}
```

### Get Item
```bash
GET /items/{id}
```

### Update Item
```bash
PUT /items/{id}
Content-Type: application/json

{
  "name": "Updated Item",
  "category": "electronics",
  "price": 39.99
}
```

### Delete Item
```bash
DELETE /items/{id}
```

## Testing

### Local Testing (Before Deployment)

Test Lambda functions locally before pushing to AWS:

```bash
# Test all functions at once
./scripts/test-functions-locally.sh

# Test individual functions with SAM Local
cd infrastructure
sam build
sam local invoke CreateItemFunction --event ../events/create-item-event.json
sam local invoke GetItemFunction --event ../events/get-item-event.json

# Run full API locally
sam local start-api --template-file stacks/02-api-and-functions.yaml
# Then test: curl http://localhost:3000/items

# Run unit tests
cd functions/get-item && npm test
cd functions/create-item && go test -v
```

### Remote Testing (After Deployment)

Test deployed API endpoints:
```bash
./infrastructure/scripts/test-api.sh dev
```