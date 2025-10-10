package main

import (
	"context"
	"encoding/json"
	"fmt"
	"os"
	"time"

	"github.com/aws/aws-lambda-go/events"
	"github.com/aws/aws-lambda-go/lambda"
	"github.com/aws/aws-sdk-go/aws"
	"github.com/aws/aws-sdk-go/aws/awserr"
	"github.com/aws/aws-sdk-go/aws/session"
	"github.com/aws/aws-sdk-go/service/dynamodb"
	"github.com/google/uuid"
)

// ErrorResponse represents an error response
type ErrorResponse struct {
	Error     string `json:"error"`
	Message   string `json:"message"`
	RequestID string `json:"requestId,omitempty"`
}

// Global variables
var (
	dynamoClient *dynamodb.DynamoDB
	tableName    string
	logger       *Logger
)

// Initialize DynamoDB client
func init() {
	// Get table name from environment
	tableName = os.Getenv("DYNAMODB_TABLE_NAME")
	if tableName == "" {
		tableName = "serverless-crud-api-items"
	}

	// Initialize AWS session
	sess, err := session.NewSession(&aws.Config{
		Region: aws.String(os.Getenv("AWS_REGION")),
	})
	if err != nil {
		panic(fmt.Sprintf("Failed to create AWS session: %v", err))
	}

	// Override endpoint for local development
	if endpoint := os.Getenv("DYNAMODB_ENDPOINT"); endpoint != "" {
		sess.Config.Endpoint = aws.String(endpoint)
	}

	// Create DynamoDB client
	dynamoClient = dynamodb.New(sess)

	// Initialize logger
	functionName := os.Getenv("AWS_LAMBDA_FUNCTION_NAME")
	if functionName == "" {
		functionName = "delete-item-function"
	}

	logger = NewLogger(LogContext{
		FunctionName: functionName,
		Operation:    "deleteItem",
	}, getEnvLogLevel())
}

// HandleRequest handles the Lambda function request for deleting an item
func HandleRequest(ctx context.Context, request events.APIGatewayProxyRequest) (events.APIGatewayProxyResponse, error) {
	// Generate request ID for tracing
	requestID := generateRequestID()

	// Create request-specific logger
	requestLogger := logger.WithContext(LogContext{
		RequestID: requestID,
	})

	requestLogger.Info("Delete item request received", map[string]interface{}{
		"httpMethod": request.HTTPMethod,
		"resource":   request.Resource,
	})

	// Set CORS headers
	headers := map[string]string{
		"Content-Type":                 "application/json",
		"Access-Control-Allow-Origin":  "*",
		"Access-Control-Allow-Methods": "DELETE, OPTIONS",
		"Access-Control-Allow-Headers": "Content-Type, Authorization",
	}

	// Handle preflight OPTIONS request
	if request.HTTPMethod == "OPTIONS" {
		return events.APIGatewayProxyResponse{
			StatusCode: 200,
			Headers:    headers,
			Body:       "",
		}, nil
	}

	// Extract item ID from path parameters
	itemID, exists := request.PathParameters["id"]
	if !exists || itemID == "" {
		requestLogger.Warn("Missing item ID in path parameters", nil)
		return createErrorResponse(400, "Item ID is required", requestID, headers), nil
	}

	// Validate UUID format
	if !isValidUUID(itemID) {
		requestLogger.Warn("Invalid UUID format", map[string]interface{}{
			"itemId": itemID,
		})
		return createErrorResponse(400, "Invalid item ID format", requestID, headers), nil
	}

	// Delete item from DynamoDB
	err := deleteItemFromDynamoDB(ctx, itemID, requestLogger)
	if err != nil {
		if err.Error() == "item not found" {
			requestLogger.Warn("Item not found", map[string]interface{}{
				"itemId": itemID,
			})
			return createErrorResponse(404, "Item not found", requestID, headers), nil
		}

		requestLogger.Error("Failed to delete item", err, map[string]interface{}{
			"itemId": itemID,
		})
		return createErrorResponse(500, "Failed to delete item", requestID, headers), nil
	}

	requestLogger.Info("Item deleted successfully", map[string]interface{}{
		"itemId": itemID,
	})

	// Return 204 No Content for successful deletion
	return events.APIGatewayProxyResponse{
		StatusCode: 204,
		Headers:    headers,
		Body:       "",
	}, nil
}

// deleteItemFromDynamoDB deletes an item from DynamoDB
func deleteItemFromDynamoDB(ctx context.Context, itemID string, logger *Logger) error {
	logger.Info("Deleting item from DynamoDB", map[string]interface{}{
		"itemId":    itemID,
		"tableName": tableName,
	})

	// First check if item exists
	getInput := &dynamodb.GetItemInput{
		TableName: aws.String(tableName),
		Key: map[string]*dynamodb.AttributeValue{
			"id": {
				S: aws.String(itemID),
			},
		},
	}

	startTime := time.Now()
	getResult, err := dynamoClient.GetItemWithContext(ctx, getInput)
	getDuration := time.Since(startTime)

	logger.LogDatabaseOperation("GetItem", tableName, map[string]interface{}{
		"id": itemID,
	}, getDuration)

	if err != nil {
		logger.Error("DynamoDB GetItem failed", err, map[string]interface{}{
			"tableName": tableName,
			"duration":  getDuration.String(),
		})
		return fmt.Errorf("failed to check item existence: %w", err)
	}

	// Check if item exists
	if getResult.Item == nil {
		logger.Info("Item not found during delete check", map[string]interface{}{
			"itemId": itemID,
		})
		return fmt.Errorf("item not found")
	}

	// Delete the item
	deleteInput := &dynamodb.DeleteItemInput{
		TableName: aws.String(tableName),
		Key: map[string]*dynamodb.AttributeValue{
			"id": {
				S: aws.String(itemID),
			},
		},
		ConditionExpression: aws.String("attribute_exists(id)"),
	}

	startTime = time.Now()
	_, err = dynamoClient.DeleteItemWithContext(ctx, deleteInput)
	deleteDuration := time.Since(startTime)

	logger.LogDatabaseOperation("DeleteItem", tableName, map[string]interface{}{
		"id": itemID,
	}, deleteDuration)

	if err != nil {
		logger.Error("DynamoDB DeleteItem failed", err, map[string]interface{}{
			"tableName": tableName,
			"duration":  deleteDuration.String(),
		})

		// Check for conditional check failed (item doesn't exist)
		if awsErr, ok := err.(awserr.Error); ok {
			if awsErr.Code() == dynamodb.ErrCodeConditionalCheckFailedException {
				return fmt.Errorf("item not found")
			}
		}

		return fmt.Errorf("failed to delete item: %w", err)
	}

	logger.Info("DynamoDB DeleteItem succeeded", map[string]interface{}{
		"duration": deleteDuration.String(),
	})
	return nil
}

// isValidUUID validates if a string is a valid UUID
func isValidUUID(u string) bool {
	_, err := uuid.Parse(u)
	return err == nil
}

// createErrorResponse creates a standardized error response
func createErrorResponse(statusCode int, message string, requestID string, headers map[string]string) events.APIGatewayProxyResponse {
	errorResp := ErrorResponse{
		Error:     getErrorType(statusCode),
		Message:   message,
		RequestID: requestID,
	}

	body, _ := json.Marshal(errorResp)

	return events.APIGatewayProxyResponse{
		StatusCode: statusCode,
		Headers:    headers,
		Body:       string(body),
	}
}

// getErrorType returns error type based on status code
func getErrorType(statusCode int) string {
	switch statusCode {
	case 400:
		return "BadRequest"
	case 404:
		return "NotFound"
	case 500:
		return "InternalServerError"
	default:
		return "Error"
	}
}

// generateRequestID generates a simple request ID for tracing
func generateRequestID() string {
	return uuid.New().String()[:8]
}

func main() {
	lambda.Start(HandleRequest)
}