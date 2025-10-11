# Postman Testing Guide for Serverless CRUD API

This guide provides step-by-step instructions for testing the Serverless CRUD API using Postman, covering both public access and API key authentication scenarios.

## Prerequisites

1. **Postman installed** - Download from [postman.com](https://www.postman.com/downloads/)
2. **API deployed** - Ensure your API stack is deployed to AWS
3. **API endpoint URL** - Get this from your CloudFormation stack outputs

## Getting Your API Endpoint URL

First, get your API endpoint URL from the deployed stack:

```bash
# Get the API URL from CloudFormation outputs
aws cloudformation describe-stacks \
  --stack-name serverless-crud-api-dev-api \
  --query 'Stacks[0].Outputs[?OutputKey==`ApiUrl`].OutputValue' \
  --output text
```

Example output: `https://abc123def4.execute-api.us-east-1.amazonaws.com/dev`

## Testing Scenarios

### Scenario 1: Testing Without API Key Authentication (Public Access)

If API key authentication is disabled, you can test the API directly without any authentication headers.

#### 1. Create Item (POST)

**Request:**
- **Method:** POST
- **URL:** `{{API_URL}}/items`
- **Headers:**
  - `Content-Type: application/json`
- **Body (JSON):**
```json
{
  "name": "Test Item",
  "description": "This is a test item created via Postman",
  "category": "electronics",
  "price": 29.99,
  "tags": ["test", "postman", "api"]
}
```

**Expected Response (201 Created):**
```json
{
  "id": "550e8400-e29b-41d4-a716-446655440000",
  "name": "Test Item",
  "description": "This is a test item created via Postman",
  "category": "electronics",
  "price": 29.99,
  "tags": ["test", "postman", "api"],
  "createdAt": "2024-01-15T10:30:00.000Z",
  "updatedAt": "2024-01-15T10:30:00.000Z"
}
```

#### 2. Get Item (GET)

**Request:**
- **Method:** GET
- **URL:** `{{API_URL}}/items/{{ITEM_ID}}`
- **Headers:** None required

**Expected Response (200 OK):**
```json
{
  "id": "550e8400-e29b-41d4-a716-446655440000",
  "name": "Test Item",
  "description": "This is a test item created via Postman",
  "category": "electronics",
  "price": 29.99,
  "tags": ["test", "postman", "api"],
  "createdAt": "2024-01-15T10:30:00.000Z",
  "updatedAt": "2024-01-15T10:30:00.000Z"
}
```

#### 3. Update Item (PUT)

**Request:**
- **Method:** PUT
- **URL:** `{{API_URL}}/items/{{ITEM_ID}}`
- **Headers:**
  - `Content-Type: application/json`
- **Body (JSON):**
```json
{
  "name": "Updated Test Item",
  "description": "This item has been updated via Postman",
  "category": "electronics",
  "price": 39.99,
  "tags": ["test", "postman", "api", "updated"]
}
```

**Expected Response (200 OK):**
```json
{
  "id": "550e8400-e29b-41d4-a716-446655440000",
  "name": "Updated Test Item",
  "description": "This item has been updated via Postman",
  "category": "electronics",
  "price": 39.99,
  "tags": ["test", "postman", "api", "updated"],
  "createdAt": "2024-01-15T10:30:00.000Z",
  "updatedAt": "2024-01-15T10:35:00.000Z"
}
```

#### 4. Delete Item (DELETE)

**Request:**
- **Method:** DELETE
- **URL:** `{{API_URL}}/items/{{ITEM_ID}}`
- **Headers:** None required

**Expected Response (204 No Content):**
- Empty response body
- Status code: 204

### Scenario 2: Testing With API Key Authentication

When API key authentication is enabled, you need to include the API key in your requests.

#### Step 1: Enable API Key Authentication

```bash
# Enable API key authentication
cd infrastructure
./scripts/manage-api-key.sh enable-auth --stage dev
```

This will:
1. Update the CloudFormation stack to enable API key authentication
2. Create an API key
3. Display the API key value

#### Step 2: Get Your API Key

If you need to retrieve your API key later:

```bash
# Get the API key value
./scripts/manage-api-key.sh get-key --stage dev
```

Example output:
```
API Key ID: abc123def456
API Key Value: your-secret-api-key-here
```

#### Step 3: Test API Endpoints with API Key

For all requests, add the API key header:

**Headers:**
- `X-API-Key: your-secret-api-key-here`
- `Content-Type: application/json` (for POST/PUT requests)

#### Testing Without API Key (Should Fail)

Try making a request without the `X-API-Key` header:

**Expected Response (403 Forbidden):**
```json
{
  "message": "Forbidden"
}
```

## Postman Collection Setup

### Step 1: Create Environment Variables

1. In Postman, click on "Environments" in the sidebar
2. Click "Create Environment"
3. Name it "Serverless CRUD API - Dev"
4. Add these variables:
   - `API_URL`: Your API endpoint URL
   - `API_KEY`: Your API key (if using authentication)
   - `ITEM_ID`: Will be set dynamically from create responses

### Step 2: Create Collection

1. Click "Collections" in the sidebar
2. Click "Create Collection"
3. Name it "Serverless CRUD API Tests"

### Step 3: Add Requests to Collection

Create these requests in your collection:

#### 1. Create Item
- **Method:** POST
- **URL:** `{{API_URL}}/items`
- **Headers:**
  - `Content-Type: application/json`
  - `X-API-Key: {{API_KEY}}` (if using authentication)
- **Body:** Raw JSON (see example above)
- **Tests Script:**
```javascript
// Save the item ID for use in other requests
if (pm.response.code === 201) {
    const responseJson = pm.response.json();
    pm.environment.set("ITEM_ID", responseJson.id);
}

// Test assertions
pm.test("Status code is 201", function () {
    pm.response.to.have.status(201);
});

pm.test("Response has id", function () {
    const responseJson = pm.response.json();
    pm.expect(responseJson).to.have.property('id');
});
```

#### 2. Get Item
- **Method:** GET
- **URL:** `{{API_URL}}/items/{{ITEM_ID}}`
- **Headers:**
  - `X-API-Key: {{API_KEY}}` (if using authentication)
- **Tests Script:**
```javascript
pm.test("Status code is 200", function () {
    pm.response.to.have.status(200);
});

pm.test("Response has correct structure", function () {
    const responseJson = pm.response.json();
    pm.expect(responseJson).to.have.property('id');
    pm.expect(responseJson).to.have.property('name');
    pm.expect(responseJson).to.have.property('createdAt');
});
```

#### 3. Update Item
- **Method:** PUT
- **URL:** `{{API_URL}}/items/{{ITEM_ID}}`
- **Headers:**
  - `Content-Type: application/json`
  - `X-API-Key: {{API_KEY}}` (if using authentication)
- **Body:** Raw JSON (see example above)

#### 4. Delete Item
- **Method:** DELETE
- **URL:** `{{API_URL}}/items/{{ITEM_ID}}`
- **Headers:**
  - `X-API-Key: {{API_KEY}}` (if using authentication)

## Error Testing Scenarios

### 1. Test Invalid Item ID (404 Not Found)

**Request:**
- **Method:** GET
- **URL:** `{{API_URL}}/items/invalid-id-123`

**Expected Response (404 Not Found):**
```json
{
  "error": "Item not found",
  "message": "Item with id 'invalid-id-123' does not exist"
}
```

### 2. Test Invalid JSON (400 Bad Request)

**Request:**
- **Method:** POST
- **URL:** `{{API_URL}}/items`
- **Body:** Invalid JSON like `{"name": "test"` (missing closing brace)

**Expected Response (400 Bad Request):**
```json
{
  "error": "Invalid JSON",
  "message": "Request body contains invalid JSON"
}
```

### 3. Test Missing Required Fields (400 Bad Request)

**Request:**
- **Method:** POST
- **URL:** `{{API_URL}}/items`
- **Body:**
```json
{
  "description": "Missing name field"
}
```

**Expected Response (400 Bad Request):**
```json
{
  "error": "Validation Error",
  "message": "Missing required field: name"
}
```

## Running the Collection

### Manual Testing
1. Select your environment
2. Run each request individually
3. Verify responses match expected results

### Automated Testing
1. Click "Run Collection"
2. Select your environment
3. Click "Run Serverless CRUD API Tests"
4. Review test results

## Troubleshooting

### Common Issues

1. **403 Forbidden Error**
   - Check if API key authentication is enabled
   - Verify you're including the correct `X-API-Key` header
   - Ensure the API key is valid and not expired

2. **404 Not Found Error**
   - Verify the API URL is correct
   - Check that the item ID exists (for GET/PUT/DELETE operations)
   - Ensure the API stack is deployed successfully

3. **500 Internal Server Error**
   - Check CloudWatch logs for Lambda function errors
   - Verify DynamoDB table exists and is accessible
   - Check IAM permissions for Lambda execution role

4. **CORS Errors (in browser)**
   - Verify CORS is properly configured in API Gateway
   - Check that the request includes proper headers

### Debugging Steps

1. **Check API Gateway Logs:**
```bash
aws logs tail /aws/apigateway/serverless-crud-api-dev --follow
```

2. **Check Lambda Function Logs:**
```bash
# For create-item function
aws logs tail /aws/lambda/serverless-crud-api-dev-create-item --follow

# For get-item function
aws logs tail /aws/lambda/serverless-crud-api-dev-get-item --follow
```

3. **Verify Stack Status:**
```bash
aws cloudformation describe-stacks --stack-name serverless-crud-api-dev-api
```

## API Key Management Commands

```bash
# Enable API key authentication
./scripts/manage-api-key.sh enable-auth --stage dev

# Disable API key authentication
./scripts/manage-api-key.sh disable-auth --stage dev

# Get API key value
./scripts/manage-api-key.sh get-key --stage dev

# Create additional API key
./scripts/manage-api-key.sh create-key --stage dev --api-key-name "postman-testing-key"

# Get API usage statistics
./scripts/manage-api-key.sh get-usage --stage dev
```

## Next Steps

After successful testing:

1. **Set up automated tests** using Postman's Newman CLI
2. **Create different environments** for dev/staging/prod
3. **Implement monitoring** using the API usage statistics
4. **Set up CI/CD pipeline** with automated API testing

## Security Best Practices

1. **Never commit API keys** to version control
2. **Use environment variables** for sensitive data in Postman
3. **Rotate API keys regularly** in production
4. **Monitor API usage** for unusual patterns
5. **Use HTTPS only** for all API requests