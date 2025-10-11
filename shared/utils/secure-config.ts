/**
 * Secure configuration management using AWS Secrets Manager
 */

import { SecretsManagerClient, GetSecretValueCommand } from '@aws-sdk/client-secrets-manager';
import { logger } from './logger';

// Cache for configuration to avoid repeated API calls
let configCache: DatabaseConfig | null = null;
let cacheExpiry: number = 0;
const CACHE_TTL = 5 * 60 * 1000; // 5 minutes

// Secrets Manager client
const secretsClient = new SecretsManagerClient({
  region: process.env.AWS_REGION || 'us-east-1'
});

/**
 * Database configuration interface
 */
export interface DatabaseConfig {
  tableName: string;
  region: string;
  maxRetries: number;
  timeout: number;
  connectionPoolSize: number;
  enableXRayTracing: boolean;
  logLevel: string;
}

/**
 * Default configuration fallback
 */
const DEFAULT_CONFIG: DatabaseConfig = {
  tableName: process.env.DYNAMODB_TABLE_NAME || 'serverless-crud-api-items',
  region: process.env.AWS_REGION || 'us-east-1',
  maxRetries: 3,
  timeout: 5000,
  connectionPoolSize: 10,
  enableXRayTracing: true,
  logLevel: process.env.LOG_LEVEL || 'INFO'
};

/**
 * Get database configuration from AWS Secrets Manager
 * Falls back to environment variables if Secrets Manager is not available
 */
export async function getDatabaseConfig(requestId?: string): Promise<DatabaseConfig> {
  // Return cached config if still valid
  if (configCache && Date.now() < cacheExpiry) {
    logger.debug('Using cached database configuration', { requestId });
    return configCache;
  }

  const secretArn = process.env.DATABASE_CONFIG_SECRET_ARN;
  
  // If no secret ARN is provided, use default configuration
  if (!secretArn) {
    logger.info('No database config secret ARN provided, using default configuration', { requestId });
    configCache = DEFAULT_CONFIG;
    cacheExpiry = Date.now() + CACHE_TTL;
    return configCache;
  }

  try {
    logger.debug('Retrieving database configuration from Secrets Manager', { 
      secretArn, 
      requestId 
    });

    const command = new GetSecretValueCommand({
      SecretId: secretArn
    });

    const response = await secretsClient.send(command);
    
    if (!response.SecretString) {
      throw new Error('Secret value is empty');
    }

    const secretConfig = JSON.parse(response.SecretString);
    
    // Merge with defaults to ensure all required fields are present
    const config: DatabaseConfig = {
      tableName: secretConfig.tableName || DEFAULT_CONFIG.tableName,
      region: secretConfig.region || DEFAULT_CONFIG.region,
      maxRetries: secretConfig.maxRetries || DEFAULT_CONFIG.maxRetries,
      timeout: secretConfig.timeout || DEFAULT_CONFIG.timeout,
      connectionPoolSize: secretConfig.connectionPoolSize || DEFAULT_CONFIG.connectionPoolSize,
      enableXRayTracing: secretConfig.enableXRayTracing !== undefined ? secretConfig.enableXRayTracing : DEFAULT_CONFIG.enableXRayTracing,
      logLevel: secretConfig.logLevel || DEFAULT_CONFIG.logLevel
    };

    // Cache the configuration
    configCache = config;
    cacheExpiry = Date.now() + CACHE_TTL;

    logger.info('Database configuration retrieved successfully from Secrets Manager', { 
      tableName: config.tableName,
      region: config.region,
      requestId 
    });

    return config;
  } catch (error) {
    logger.error('Failed to retrieve database configuration from Secrets Manager, using defaults', 
      error as Error, { secretArn, requestId });
    
    // Fall back to default configuration
    configCache = DEFAULT_CONFIG;
    cacheExpiry = Date.now() + CACHE_TTL;
    return configCache;
  }
}

/**
 * Validate database configuration
 */
export function validateDatabaseConfig(config: DatabaseConfig): void {
  const errors: string[] = [];

  if (!config.tableName) {
    errors.push('tableName is required');
  }

  if (!config.region) {
    errors.push('region is required');
  }

  if (config.maxRetries < 0 || config.maxRetries > 10) {
    errors.push('maxRetries must be between 0 and 10');
  }

  if (config.timeout < 1000 || config.timeout > 30000) {
    errors.push('timeout must be between 1000 and 30000 milliseconds');
  }

  if (config.connectionPoolSize < 1 || config.connectionPoolSize > 100) {
    errors.push('connectionPoolSize must be between 1 and 100');
  }

  if (errors.length > 0) {
    throw new Error(`Invalid database configuration: ${errors.join(', ')}`);
  }
}

/**
 * Clear configuration cache (useful for testing)
 */
export function clearConfigCache(): void {
  configCache = null;
  cacheExpiry = 0;
}

/**
 * Get configuration for specific environment
 */
export async function getEnvironmentConfig(stage: string, requestId?: string): Promise<DatabaseConfig> {
  const config = await getDatabaseConfig(requestId);
  
  // Apply environment-specific overrides
  switch (stage.toLowerCase()) {
    case 'dev':
    case 'development':
      return {
        ...config,
        logLevel: 'DEBUG',
        maxRetries: 2, // Faster failures in development
        timeout: 3000
      };
    
    case 'staging':
      return {
        ...config,
        logLevel: 'INFO',
        maxRetries: 3,
        timeout: 5000
      };
    
    case 'prod':
    case 'production':
      return {
        ...config,
        logLevel: 'WARN',
        maxRetries: 5, // More resilient in production
        timeout: 8000,
        connectionPoolSize: 20 // Higher pool size for production
      };
    
    default:
      return config;
  }
}

/**
 * Create secure connection string for logging (without sensitive data)
 */
export function createSecureLogString(config: DatabaseConfig): string {
  return `DynamoDB(table=${config.tableName}, region=${config.region}, retries=${config.maxRetries})`;
}