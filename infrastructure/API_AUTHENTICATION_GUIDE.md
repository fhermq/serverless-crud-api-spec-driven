# API Authentication Guide

This guide explains how to configure and use API key authentication for the Serverless CRUD API.

## Overview

The API supports optional API key authentication with the following features:

- ✅ **API Key Authentication**: Secure access using X-API-Key header
- ✅ **Usage Plans**: Rate limiting and quotas per API key
- ✅ **Throttling**: Request rate limiting (100 req/sec, 200 burst)
- ✅ **Daily Quotas**: 10,000 requests per day per API key
- ✅ **Request Validation**: JSON schema validation at API Gateway level
- ✅ **CORS Support**: Proper CORS headers for web applications

## Quick Setup

### Enable API Key Authentication

```bash
# Enable authentication for development
cd infrastructure
./scripts/manage-api-key.sh enable-auth --stage dev

# Enable authentication for production with custom key name
./scripts/manage-api-key.sh enable-auth --stage prod --api-key-name prod-api-key
```

### Retrieve API Key

```bash
# Get the API key value
./scripts/manage-api-key.sh get-key --stage dev
```

### Use API Key in Requests

```bash
# Include API key in requests
curl -H "X-API-Key: YOUR_API_KEY_VALUE" \
     -H "Content-Type: application/json" \
     https://your-api-url/items

# Create item with API key
curl -X POST \
     -H "X-API-Key: YOUR_API_KEY_VALUE" \
     -H "Content-Type: application/json" \
     -d '{"name":"Test Item","category":"test","price":10.99}' \
     https://your-api-url/items
```

## Configuration Options

### Deployment Parameters

When deploying the API stack, you can configure authentication:

```bash
# Deploy without authentication (default)
sam deploy --template-file stacks/02-api-and-functions.yaml \
  --parameter-overrides \
    FoundationStackName=serverless-crud-api-dev-foundation \
    EnableApiKeyAuth=false

# Deploy with authentication enabled
sam deploy --template-file stacks/02-api-and-functions.yaml \
  --parameter-overrides \
    FoundationStackName=serverless-crud-api-dev-foundation \
    EnableApiKeyAuth=true \
    ApiKeyName=my-custom-api-key
```

### Usage Plan Configuration

The default usage plan includes:

- **Rate Limit**: 100 requests per second
- **Burst Limit**: 200 requests (burst capacity)
- **Daily Quota**: 10,000 requests per day
- **Throttling**: Automatic throttling when limits exceeded

To modify these limits, update the `ApiUsagePlan` resource in `02-api-and-functions.yaml`:

```yaml
ApiUsagePlan:
  Type: AWS::ApiGateway::UsagePlan
  Properties:
    Throttle:
      RateLimit: 200    # requests per second
      BurstLimit: 400   # burst capacity
    Quota:
      Limit: 50000      # requests per period
      Period: DAY       # daily quota
```

## API Key Management

### Available Commands

```bash
# Get API key value
./scripts/manage-api-key.sh get-key --stage dev

# Enable API key authentication
./scripts/manage-api-key.sh enable-auth --stage dev

# Disable API key authentication
./scripts/manage-api-key.sh disable-auth --stage dev

# Create additional API key
./scripts/manage-api-key.sh create-key --stage dev --api-key-name additional-key

# Get usage statistics
./scripts/manage-api-key.sh get-usage --stage dev
```

### Multiple API Keys

You can create multiple API keys for the same API:

```bash
# Create additional keys for different clients
./scripts/manage-api-key.sh create-key --stage prod --api-key-name mobile-app-key
./scripts/manage-api-key.sh create-key --stage prod --api-key-name web-app-key
./scripts/manage-api-key.sh create-key --stage prod --api-key-name partner-api-key
```

All keys share the same usage plan and limits.

## Request Validation

### Automatic Validation

The API Gateway performs automatic validation for:

- **Request Parameters**: Path parameters (e.g., item ID format)
- **Request Body**: JSON schema validation for POST/PUT requests
- **Content Type**: Ensures proper Content-Type headers

### Validation Errors

Invalid requests return `400 Bad Request` with detailed error messages:

```json
{
  "error": "Bad Request",
  "message": "Invalid request body",
  "details": ["Missing required field: name"]
}
```

## Error Responses

### Authentication Errors

**401 Unauthorized** - Missing API key:
```json
{
  "error": "Unauthorized",
  "message": "API key required. Please include a valid API key in the X-API-Key header."
}
```

**403 Forbidden** - Invalid API key or quota exceeded:
```json
{
  "error": "Forbidden",
  "message": "API key is invalid or usage limit exceeded."
}
```

### Rate Limiting Errors

**429 Too Many Requests** - Rate limit exceeded:
```json
{
  "error": "Too Many Requests",
  "message": "Request rate limit exceeded. Please try again later."
}
```

## Usage Monitoring

### View Usage Statistics

```bash
# Get detailed usage statistics
./scripts/manage-api-key.sh get-usage --stage prod
```

### CloudWatch Metrics

Monitor API usage through CloudWatch:

- **API Gateway Metrics**: Request count, latency, errors
- **Custom Metrics**: API key usage, throttling events
- **Alarms**: Set up alerts for high error rates or quota limits

### Access Logs

API Gateway access logs include:

```json
{
  "requestId": "12345678-1234-1234-1234-123456789012",
  "requestTime": "2024-01-15T10:30:00Z",
  "httpMethod": "POST",
  "resourcePath": "/items",
  "status": 201,
  "responseLength": 156,
  "responseTime": 45,
  "userAgent": "curl/7.68.0",
  "sourceIp": "203.0.113.1",
  "apiKeyId": "abcd1234"
}
```

## Security Best Practices

### API Key Security

1. **Keep Keys Secret**: Never commit API keys to version control
2. **Use Environment Variables**: Store keys in secure environment variables
3. **Rotate Keys Regularly**: Create new keys and deactivate old ones periodically
4. **Monitor Usage**: Watch for unusual usage patterns
5. **Use HTTPS Only**: Always use HTTPS for API requests

### Client-Side Usage

```javascript
// Store API key securely (not in client-side code)
const API_KEY = process.env.REACT_APP_API_KEY; // Server-side only

// Include in requests
const response = await fetch('https://api.example.com/items', {
  method: 'GET',
  headers: {
    'X-API-Key': API_KEY,
    'Content-Type': 'application/json'
  }
});
```

### Server-Side Usage

```python
import os
import requests

# Get API key from environment
api_key = os.environ.get('API_KEY')

# Make authenticated request
response = requests.get(
    'https://api.example.com/items',
    headers={
        'X-API-Key': api_key,
        'Content-Type': 'application/json'
    }
)
```

## CORS Configuration

The API is configured with CORS support for web applications:

- **Allowed Origins**: `*` (configure for specific domains in production)
- **Allowed Methods**: `GET, POST, PUT, DELETE, OPTIONS`
- **Allowed Headers**: Includes `X-API-Key` for authentication
- **Credentials**: Not required for API key authentication

### Custom CORS Configuration

For production, consider restricting origins:

```yaml
Cors:
  AllowMethods: "'GET,POST,PUT,DELETE,OPTIONS'"
  AllowHeaders: "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token,X-Requested-With'"
  AllowOrigin: "'https://yourdomain.com'"  # Restrict to specific domain
  AllowCredentials: false
```

## Troubleshooting

### Common Issues

**1. "API key required" error**
- Ensure you're including the `X-API-Key` header
- Verify the header name is exactly `X-API-Key` (case-sensitive)
- Check that API key authentication is enabled

**2. "Invalid API key" error**
- Verify the API key value is correct
- Check that the API key is enabled
- Ensure the key is associated with the usage plan

**3. "Usage limit exceeded" error**
- Check daily quota limits
- Monitor rate limiting thresholds
- Consider creating additional API keys or increasing limits

**4. CORS errors in browser**
- Verify CORS configuration includes `X-API-Key` in allowed headers
- Check that preflight OPTIONS requests are handled correctly
- Ensure API Gateway responses include proper CORS headers

### Debugging Steps

1. **Verify API Key**:
   ```bash
   ./scripts/manage-api-key.sh get-key --stage dev
   ```

2. **Check Usage Statistics**:
   ```bash
   ./scripts/manage-api-key.sh get-usage --stage dev
   ```

3. **Test Without Authentication**:
   ```bash
   # Disable auth temporarily for testing
   ./scripts/manage-api-key.sh disable-auth --stage dev
   ```

4. **Check CloudWatch Logs**:
   ```bash
   aws logs tail /aws/apigateway/serverless-crud-api-dev --follow
   ```

## Migration Guide

### From No Authentication to API Key

1. **Deploy with authentication enabled**:
   ```bash
   ./scripts/manage-api-key.sh enable-auth --stage dev
   ```

2. **Update client applications** to include API key header

3. **Test thoroughly** before deploying to production

4. **Monitor usage** and error rates after deployment

### From API Key to Other Authentication

To migrate to JWT or other authentication methods:

1. Update the API Gateway configuration
2. Modify Lambda functions to handle new auth method
3. Update client applications
4. Gradually migrate users to new authentication

## Environment-Specific Configuration

### Development Environment
- API key authentication optional
- Higher rate limits for testing
- Detailed error messages

### Production Environment
- API key authentication required
- Conservative rate limits
- Generic error messages
- Restricted CORS origins

### Example Deployment

```bash
# Development - no authentication
./scripts/deploy-api-and-functions.sh --stage dev --region us-east-1

# Production - with authentication
./scripts/manage-api-key.sh enable-auth --stage prod --region us-west-2
```

## Support

For issues with API authentication:

1. Check the troubleshooting section above
2. Review CloudWatch logs for detailed error information
3. Verify API Gateway configuration in AWS Console
4. Test with curl or Postman to isolate client issues
5. Monitor usage statistics for quota and rate limit issues

## References

- [AWS API Gateway API Keys Documentation](https://docs.aws.amazon.com/apigateway/latest/developerguide/api-gateway-api-usage-plans.html)
- [API Gateway Usage Plans](https://docs.aws.amazon.com/apigateway/latest/developerguide/api-gateway-api-usage-plans.html)
- [API Gateway Request Validation](https://docs.aws.amazon.com/apigateway/latest/developerguide/api-gateway-method-request-validation.html)
- [API Gateway CORS](https://docs.aws.amazon.com/apigateway/latest/developerguide/how-to-cors.html)