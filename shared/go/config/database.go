package config

import (
	"context"
	"encoding/json"
	"fmt"
	"log"
	"os"
	"strconv"
	"sync"
	"time"

	"github.com/aws/aws-sdk-go/aws"
	"github.com/aws/aws-sdk-go/aws/session"
	"github.com/aws/aws-sdk-go/service/secretsmanager"
)

// DatabaseConfig represents the database configuration
type DatabaseConfig struct {
	TableName            string `json:"tableName"`
	Region               string `json:"region"`
	MaxRetries           int    `json:"maxRetries"`
	Timeout              int    `json:"timeout"`
	ConnectionPoolSize   int    `json:"connectionPoolSize"`
	EnableXRayTracing    bool   `json:"enableXRayTracing"`
	LogLevel             string `json:"logLevel"`
}

// ConfigCache holds cached configuration with expiry
type ConfigCache struct {
	config *DatabaseConfig
	expiry time.Time
	mutex  sync.RWMutex
}

var (
	configCache = &ConfigCache{}
	cacheTTL    = 5 * time.Minute
)

// GetDatabaseConfig retrieves database configuration from AWS Secrets Manager
// Falls back to environment variables if Secrets Manager is not available
func GetDatabaseConfig(ctx context.Context, requestID string) (*DatabaseConfig, error) {
	// Check cache first
	configCache.mutex.RLock()
	if configCache.config != nil && time.Now().Before(configCache.expiry) {
		log.Printf("[INFO] Using cached database configuration (requestId: %s)", requestID)
		defer configCache.mutex.RUnlock()
		return configCache.config, nil
	}
	configCache.mutex.RUnlock()

	// Get configuration from Secrets Manager or environment
	config, err := loadConfiguration(ctx, requestID)
	if err != nil {
		return nil, fmt.Errorf("failed to load database configuration: %w", err)
	}

	// Validate configuration
	if err := validateConfig(config); err != nil {
		return nil, fmt.Errorf("invalid database configuration: %w", err)
	}

	// Cache the configuration
	configCache.mutex.Lock()
	configCache.config = config
	configCache.expiry = time.Now().Add(cacheTTL)
	configCache.mutex.Unlock()

	log.Printf("[INFO] Database configuration loaded successfully (table: %s, region: %s, requestId: %s)", 
		config.TableName, config.Region, requestID)

	return config, nil
}

// loadConfiguration loads configuration from Secrets Manager or environment variables
func loadConfiguration(ctx context.Context, requestID string) (*DatabaseConfig, error) {
	secretARN := os.Getenv("DATABASE_CONFIG_SECRET_ARN")
	
	// If no secret ARN is provided, use environment variables
	if secretARN == "" {
		log.Printf("[INFO] No database config secret ARN provided, using environment variables (requestId: %s)", requestID)
		return getDefaultConfig(), nil
	}

	// Try to get configuration from Secrets Manager
	config, err := getConfigFromSecretsManager(ctx, secretARN, requestID)
	if err != nil {
		log.Printf("[ERROR] Failed to retrieve config from Secrets Manager, using defaults: %v (requestId: %s)", err, requestID)
		return getDefaultConfig(), nil
	}

	return config, nil
}

// getConfigFromSecretsManager retrieves configuration from AWS Secrets Manager
func getConfigFromSecretsManager(ctx context.Context, secretARN, requestID string) (*DatabaseConfig, error) {
	log.Printf("[DEBUG] Retrieving database configuration from Secrets Manager (secretArn: %s, requestId: %s)", 
		secretARN, requestID)

	// Create AWS session
	sess, err := session.NewSession(&aws.Config{
		Region: aws.String(os.Getenv("AWS_REGION")),
	})
	if err != nil {
		return nil, fmt.Errorf("failed to create AWS session: %w", err)
	}

	// Create Secrets Manager client
	svc := secretsmanager.New(sess)

	// Get secret value
	input := &secretsmanager.GetSecretValueInput{
		SecretId: aws.String(secretARN),
	}

	result, err := svc.GetSecretValueWithContext(ctx, input)
	if err != nil {
		return nil, fmt.Errorf("failed to get secret value: %w", err)
	}

	if result.SecretString == nil {
		return nil, fmt.Errorf("secret value is empty")
	}

	// Parse JSON configuration
	var secretConfig map[string]interface{}
	if err := json.Unmarshal([]byte(*result.SecretString), &secretConfig); err != nil {
		return nil, fmt.Errorf("failed to parse secret JSON: %w", err)
	}

	// Build configuration with defaults
	config := getDefaultConfig()
	
	if tableName, ok := secretConfig["tableName"].(string); ok && tableName != "" {
		config.TableName = tableName
	}
	
	if region, ok := secretConfig["region"].(string); ok && region != "" {
		config.Region = region
	}
	
	if maxRetries, ok := secretConfig["maxRetries"].(float64); ok {
		config.MaxRetries = int(maxRetries)
	}
	
	if timeout, ok := secretConfig["timeout"].(float64); ok {
		config.Timeout = int(timeout)
	}
	
	if poolSize, ok := secretConfig["connectionPoolSize"].(float64); ok {
		config.ConnectionPoolSize = int(poolSize)
	}
	
	if xrayTracing, ok := secretConfig["enableXRayTracing"].(bool); ok {
		config.EnableXRayTracing = xrayTracing
	}
	
	if logLevel, ok := secretConfig["logLevel"].(string); ok && logLevel != "" {
		config.LogLevel = logLevel
	}

	log.Printf("[INFO] Database configuration retrieved from Secrets Manager (requestId: %s)", requestID)
	return config, nil
}

// getDefaultConfig returns default configuration from environment variables
func getDefaultConfig() *DatabaseConfig {
	config := &DatabaseConfig{
		TableName:            getEnvString("DYNAMODB_TABLE_NAME", "serverless-crud-api-items"),
		Region:               getEnvString("AWS_REGION", "us-east-1"),
		MaxRetries:           getEnvInt("MAX_RETRIES", 3),
		Timeout:              getEnvInt("TIMEOUT_MS", 5000),
		ConnectionPoolSize:   getEnvInt("CONNECTION_POOL_SIZE", 10),
		EnableXRayTracing:    getEnvBool("ENABLE_XRAY_TRACING", true),
		LogLevel:             getEnvString("LOG_LEVEL", "INFO"),
	}

	return config
}

// validateConfig validates the database configuration
func validateConfig(config *DatabaseConfig) error {
	if config.TableName == "" {
		return fmt.Errorf("tableName is required")
	}

	if config.Region == "" {
		return fmt.Errorf("region is required")
	}

	if config.MaxRetries < 0 || config.MaxRetries > 10 {
		return fmt.Errorf("maxRetries must be between 0 and 10")
	}

	if config.Timeout < 1000 || config.Timeout > 30000 {
		return fmt.Errorf("timeout must be between 1000 and 30000 milliseconds")
	}

	if config.ConnectionPoolSize < 1 || config.ConnectionPoolSize > 100 {
		return fmt.Errorf("connectionPoolSize must be between 1 and 100")
	}

	return nil
}

// GetEnvironmentConfig returns configuration optimized for specific environment
func GetEnvironmentConfig(ctx context.Context, stage, requestID string) (*DatabaseConfig, error) {
	config, err := GetDatabaseConfig(ctx, requestID)
	if err != nil {
		return nil, err
	}

	// Apply environment-specific overrides
	switch stage {
	case "dev", "development":
		config.LogLevel = "DEBUG"
		config.MaxRetries = 2 // Faster failures in development
		config.Timeout = 3000
	case "staging":
		config.LogLevel = "INFO"
		config.MaxRetries = 3
		config.Timeout = 5000
	case "prod", "production":
		config.LogLevel = "WARN"
		config.MaxRetries = 5 // More resilient in production
		config.Timeout = 8000
		config.ConnectionPoolSize = 20 // Higher pool size for production
	}

	return config, nil
}

// CreateSecureLogString creates a secure log string without sensitive data
func CreateSecureLogString(config *DatabaseConfig) string {
	return fmt.Sprintf("DynamoDB(table=%s, region=%s, retries=%d)", 
		config.TableName, config.Region, config.MaxRetries)
}

// ClearConfigCache clears the configuration cache (useful for testing)
func ClearConfigCache() {
	configCache.mutex.Lock()
	defer configCache.mutex.Unlock()
	configCache.config = nil
	configCache.expiry = time.Time{}
}

// Helper functions for environment variables
func getEnvString(key, defaultValue string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}
	return defaultValue
}

func getEnvInt(key string, defaultValue int) int {
	if value := os.Getenv(key); value != "" {
		if intValue, err := strconv.Atoi(value); err == nil {
			return intValue
		}
	}
	return defaultValue
}

func getEnvBool(key string, defaultValue bool) bool {
	if value := os.Getenv(key); value != "" {
		if boolValue, err := strconv.ParseBool(value); err == nil {
			return boolValue
		}
	}
	return defaultValue
}