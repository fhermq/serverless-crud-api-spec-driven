# API Documentation

## OpenAPI Specification

The complete API specification is available in `api-spec.yaml` (OpenAPI 3.0 format).

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

Test all endpoints:
```bash
./infrastructure/scripts/test-api.sh dev
```