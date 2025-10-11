package database

import (
	"context"
	"fmt"
	"log"
	"sync"
	"time"

	"github.com/aws/aws-sdk-go/aws"
	"github.com/aws/aws-sdk-go/aws/session"
	"github.com/aws/aws-sdk-go/service/dynamodb"
	"github.com/serverless-crud-api/shared/config"
)

// SecureDynamoDBClient wraps DynamoDB client with secure configuration
type SecureDynamoDBClient struct {
	client *dynamodb.DynamoDB
	config *config.DatabaseConfig
	mutex  sync.RWMutex
}

var (
	clientCache *SecureDynamoDBClient
	clientMutex sync.Mutex
)

// GetSecureDynamoDBClient returns a DynamoDB client with secure configuration
func GetSecureDynamoDBClient(ctx context.Context, requestID string) (*SecureDynamoDBClient, error) {
	clientMutex.Lock()
	defer clientMutex.Unlock()

	// Return cached client if available
	if clientCache != nil {
		return clientCache, nil
	}

	// Get database configuration
	dbConfig, err := config.GetDatabaseConfig(ctx, requestID)
	if err != nil {
		return nil, fmt.Errorf("failed to get database configuration: %w", err)
	}

	log.Printf("[DEBUG] Creating DynamoDB client with secure configuration (config: %s, requestId: %s)", 
		config.CreateSecureLogString(dbConfig), requestID)

	// Create AWS session with configuration
	sess, err := session.NewSession(&aws.Config{
		Region:     aws.String(dbConfig.Region),
		MaxRetries: aws.Int(dbConfig.MaxRetries),
	})
	if err != nil {
		return nil, fmt.Errorf("failed to create AWS session: %w", err)
	}

	// Create DynamoDB client
	client := dynamodb.New(sess)

	// Create secure client wrapper
	secureClient := &SecureDynamoDBClient{
		client: client,
		config: dbConfig,
	}

	// Cache the client
	clientCache = secureClient

	log.Printf("[INFO] DynamoDB client created successfully (config: %s, xrayEnabled: %t, requestId: %s)", 
		config.CreateSecureLogString(dbConfig), dbConfig.EnableXRayTracing, requestID)

	return secureClient, nil
}

// GetClient returns the underlying DynamoDB client
func (c *SecureDynamoDBClient) GetClient() *dynamodb.DynamoDB {
	c.mutex.RLock()
	defer c.mutex.RUnlock()
	return c.client
}

// GetConfig returns the database configuration
func (c *SecureDynamoDBClient) GetConfig() *config.DatabaseConfig {
	c.mutex.RLock()
	defer c.mutex.RUnlock()
	return c.config
}

// GetTableName returns the configured table name
func (c *SecureDynamoDBClient) GetTableName() string {
	c.mutex.RLock()
	defer c.mutex.RUnlock()
	return c.config.TableName
}

// PutItemWithRetry performs a PutItem operation with retry logic
func (c *SecureDynamoDBClient) PutItemWithRetry(ctx context.Context, input *dynamodb.PutItemInput, requestID string) (*dynamodb.PutItemOutput, error) {
	startTime := time.Now()
	
	// Set table name from configuration
	if input.TableName == nil {
		input.TableName = aws.String(c.GetTableName())
	}

	var lastErr error
	maxRetries := c.GetConfig().MaxRetries

	for attempt := 0; attempt <= maxRetries; attempt++ {
		if attempt > 0 {
			// Exponential backoff
			backoff := time.Duration(attempt*attempt) * 100 * time.Millisecond
			log.Printf("[DEBUG] Retrying PutItem after %v (attempt %d/%d, requestId: %s)", 
				backoff, attempt, maxRetries, requestID)
			time.Sleep(backoff)
		}

		result, err := c.client.PutItemWithContext(ctx, input)
		if err == nil {
			duration := time.Since(startTime)
			log.Printf("[DEBUG] PutItem successful (duration: %v, attempts: %d, requestId: %s)", 
				duration, attempt+1, requestID)
			return result, nil
		}

		lastErr = err
		
		// Check if error is retryable
		if !isRetryableError(err) {
			break
		}
	}

	duration := time.Since(startTime)
	log.Printf("[ERROR] PutItem failed after %d attempts (duration: %v, requestId: %s): %v", 
		maxRetries+1, duration, requestID, lastErr)
	
	return nil, lastErr
}

// GetItemWithRetry performs a GetItem operation with retry logic
func (c *SecureDynamoDBClient) GetItemWithRetry(ctx context.Context, input *dynamodb.GetItemInput, requestID string) (*dynamodb.GetItemOutput, error) {
	startTime := time.Now()
	
	// Set table name from configuration
	if input.TableName == nil {
		input.TableName = aws.String(c.GetTableName())
	}

	var lastErr error
	maxRetries := c.GetConfig().MaxRetries

	for attempt := 0; attempt <= maxRetries; attempt++ {
		if attempt > 0 {
			// Exponential backoff
			backoff := time.Duration(attempt*attempt) * 100 * time.Millisecond
			log.Printf("[DEBUG] Retrying GetItem after %v (attempt %d/%d, requestId: %s)", 
				backoff, attempt, maxRetries, requestID)
			time.Sleep(backoff)
		}

		result, err := c.client.GetItemWithContext(ctx, input)
		if err == nil {
			duration := time.Since(startTime)
			log.Printf("[DEBUG] GetItem successful (duration: %v, attempts: %d, requestId: %s)", 
				duration, attempt+1, requestID)
			return result, nil
		}

		lastErr = err
		
		// Check if error is retryable
		if !isRetryableError(err) {
			break
		}
	}

	duration := time.Since(startTime)
	log.Printf("[ERROR] GetItem failed after %d attempts (duration: %v, requestId: %s): %v", 
		maxRetries+1, duration, requestID, lastErr)
	
	return nil, lastErr
}

// UpdateItemWithRetry performs an UpdateItem operation with retry logic
func (c *SecureDynamoDBClient) UpdateItemWithRetry(ctx context.Context, input *dynamodb.UpdateItemInput, requestID string) (*dynamodb.UpdateItemOutput, error) {
	startTime := time.Now()
	
	// Set table name from configuration
	if input.TableName == nil {
		input.TableName = aws.String(c.GetTableName())
	}

	var lastErr error
	maxRetries := c.GetConfig().MaxRetries

	for attempt := 0; attempt <= maxRetries; attempt++ {
		if attempt > 0 {
			// Exponential backoff
			backoff := time.Duration(attempt*attempt) * 100 * time.Millisecond
			log.Printf("[DEBUG] Retrying UpdateItem after %v (attempt %d/%d, requestId: %s)", 
				backoff, attempt, maxRetries, requestID)
			time.Sleep(backoff)
		}

		result, err := c.client.UpdateItemWithContext(ctx, input)
		if err == nil {
			duration := time.Since(startTime)
			log.Printf("[DEBUG] UpdateItem successful (duration: %v, attempts: %d, requestId: %s)", 
				duration, attempt+1, requestID)
			return result, nil
		}

		lastErr = err
		
		// Check if error is retryable
		if !isRetryableError(err) {
			break
		}
	}

	duration := time.Since(startTime)
	log.Printf("[ERROR] UpdateItem failed after %d attempts (duration: %v, requestId: %s): %v", 
		maxRetries+1, duration, requestID, lastErr)
	
	return nil, lastErr
}

// DeleteItemWithRetry performs a DeleteItem operation with retry logic
func (c *SecureDynamoDBClient) DeleteItemWithRetry(ctx context.Context, input *dynamodb.DeleteItemInput, requestID string) (*dynamodb.DeleteItemOutput, error) {
	startTime := time.Now()
	
	// Set table name from configuration
	if input.TableName == nil {
		input.TableName = aws.String(c.GetTableName())
	}

	var lastErr error
	maxRetries := c.GetConfig().MaxRetries

	for attempt := 0; attempt <= maxRetries; attempt++ {
		if attempt > 0 {
			// Exponential backoff
			backoff := time.Duration(attempt*attempt) * 100 * time.Millisecond
			log.Printf("[DEBUG] Retrying DeleteItem after %v (attempt %d/%d, requestId: %s)", 
				backoff, attempt, maxRetries, requestID)
			time.Sleep(backoff)
		}

		result, err := c.client.DeleteItemWithContext(ctx, input)
		if err == nil {
			duration := time.Since(startTime)
			log.Printf("[DEBUG] DeleteItem successful (duration: %v, attempts: %d, requestId: %s)", 
				duration, attempt+1, requestID)
			return result, nil
		}

		lastErr = err
		
		// Check if error is retryable
		if !isRetryableError(err) {
			break
		}
	}

	duration := time.Since(startTime)
	log.Printf("[ERROR] DeleteItem failed after %d attempts (duration: %v, requestId: %s): %v", 
		maxRetries+1, duration, requestID, lastErr)
	
	return nil, lastErr
}

// HealthCheck performs a health check on the DynamoDB connection
func (c *SecureDynamoDBClient) HealthCheck(ctx context.Context, requestID string) error {
	log.Printf("[DEBUG] Performing DynamoDB health check (requestId: %s)", requestID)
	
	// Try to get a non-existent item to test connectivity
	input := &dynamodb.GetItemInput{
		TableName: aws.String(c.GetTableName()),
		Key: map[string]*dynamodb.AttributeValue{
			"id": {
				S: aws.String("health-check-non-existent-id"),
			},
		},
	}

	_, err := c.client.GetItemWithContext(ctx, input)
	if err != nil {
		log.Printf("[ERROR] DynamoDB health check failed (requestId: %s): %v", requestID, err)
		return fmt.Errorf("DynamoDB health check failed: %w", err)
	}

	log.Printf("[INFO] DynamoDB health check passed (requestId: %s)", requestID)
	return nil
}

// isRetryableError determines if an error is retryable
func isRetryableError(err error) bool {
	if err == nil {
		return false
	}

	// Check for specific retryable errors
	errorString := err.Error()
	
	// Throttling errors
	if contains(errorString, "ProvisionedThroughputExceededException") ||
		contains(errorString, "ThrottlingException") ||
		contains(errorString, "RequestLimitExceeded") {
		return true
	}

	// Service errors
	if contains(errorString, "ServiceUnavailable") ||
		contains(errorString, "InternalServerError") ||
		contains(errorString, "ServiceException") {
		return true
	}

	// Network errors
	if contains(errorString, "connection") ||
		contains(errorString, "timeout") ||
		contains(errorString, "network") {
		return true
	}

	return false
}

// contains checks if a string contains a substring (case-insensitive)
func contains(s, substr string) bool {
	return len(s) >= len(substr) && 
		(s == substr || 
		 (len(s) > len(substr) && 
		  (s[:len(substr)] == substr || 
		   s[len(s)-len(substr):] == substr || 
		   containsSubstring(s, substr))))
}

func containsSubstring(s, substr string) bool {
	for i := 0; i <= len(s)-len(substr); i++ {
		if s[i:i+len(substr)] == substr {
			return true
		}
	}
	return false
}

// ClearClientCache clears the client cache (useful for testing)
func ClearClientCache() {
	clientMutex.Lock()
	defer clientMutex.Unlock()
	clientCache = nil
	log.Printf("[DEBUG] DynamoDB client cache cleared")
}