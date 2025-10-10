package main

import (
	"context"
	"encoding/json"
	"fmt"
	"log"
	"os"
	"strings"
	"time"

	"github.com/aws/aws-lambda-go/events"
	"github.com/aws/aws-lambda-go/lambda"
	"github.com/aws/aws-sdk-go/aws"
	"github.com/aws/aws-sdk-go/aws/awserr"
	"github.com/aws/aws-sdk-go/aws/session"
	"github.com/aws/aws-sdk-go/service/dynamodb"
	"github.com/aws/aws-sdk-go/service/dynamodb/dynamodbattribute"
	validator "github.com/go-playground/validator/v10"
	"github.com/google/uuid"
)

// CreateItemRequest represents the request payload for creating an item
type CreateItemRequest struct {
	Name        string  `json:"name" validate:"required,min=1,max=100"`
	Description *string `json:"description,omitempty" validate:"omitempty,max=500"`
	Category    string  `json:"category" validate:"required,oneof=electronics clothing books home sports other"`
	Price       float64 `json:"price" validate:"required,gt=0"`
}

// Item represents the complete item structure
type Item struct {
	ID          string  `json:"id" dynamodbav:"id"`
	Name        string  `json:"name" dynamodbav:"name"`
	Description *string `json:"description,omitempty" dynamodbav:"description,omitempty"`
	Category    string  `json:"category" dynamodbav:"category"`
	Price       float64 `json:"price" dynamodbav:"price"`
	CreatedAt   string  `json:"createdAt" dynamodbav:"createdAt"`
	UpdatedAt   string  `json:"updatedAt" dynamodbav:"updatedAt"`
}

// ErrorResponse represents an error response
type ErrorResponse struct {
	Error   string                 `json:"error"`
	Message string                 `json:"message"`
	Details []ValidationError      `json:"details,omitempty"`
	RequestID string               `json:"requestId,omitempty"`
}

// ValidationError represents a validation error
type ValidationError struct {
	Field   string      `json:"field"`
	Message string      `json:"message"`
	Value   interface{} `json:"value,omitempty"`
}

// Global variables
var (
	dynamoClient *dynamodb.DynamoDB
	tableName    string
	validate     *validator.Validate
)

// Initialize DynamoDB client and validator
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
		log.Fatalf("Failed to create AWS session: %v", err)
	}

	// Override endpoint for local development
	if endpoint := os.Getenv("DYNAMODB_ENDPOINT"); endpoint != "" {
		sess.Config.Endpoint = aws.String(endpoint)
	}

	// Create DynamoDB client
	dynamoClient = dynamodb.New(sess)

	// Initialize validator
	validate = validator.New()
}

// HandleRequest handles the Lambda function request
func HandleRequest(ctx context.Context, request events.APIGatewayProxyRequest) (events.APIGatewayProxyResponse, error) {
	// Generate request ID for tracing
	requestID := generateRequestID()
	
	log.Printf("[%s] Received create item request", requestID)

	// Set CORS headers
	headers := map[string]string{
		"Content-Type":                 "application/json",
		"Access-Control-Allow-Origin":  "*",
		"Access-Control-Allow-Methods": "POST, OPTIONS",
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

	// Parse and validate request body
	var createReq CreateItemRequest
	if err := json.Unmarshal([]byte(request.Body), &createReq); err != nil {
		log.Printf("[%s] Failed to parse request body: %v", requestID, err)
		return createErrorResponse(400, "Invalid JSON format", nil, requestID, headers), nil
	}

	// Validate request data
	if validationErrors := validateCreateItemRequest(createReq); len(validationErrors) > 0 {
		log.Printf("[%s] Validation failed: %d errors", requestID, len(validationErrors))
		return createErrorResponse(400, "Validation failed", validationErrors, requestID, headers), nil
	}

	// Sanitize input data
	sanitizedReq := sanitizeCreateItemRequest(createReq)

	// Create item in DynamoDB
	item, err := createItemInDynamoDB(ctx, sanitizedReq, requestID)
	if err != nil {
		log.Printf("[%s] Failed to create item: %v", requestID, err)
		return createErrorResponse(500, "Failed to create item", nil, requestID, headers), nil
	}

	// Return success response
	responseBody, err := json.Marshal(item)
	if err != nil {
		log.Printf("[%s] Failed to marshal response: %v", requestID, err)
		return createErrorResponse(500, "Internal server error", nil, requestID, headers), nil
	}

	log.Printf("[%s] Item created successfully: %s", requestID, item.ID)

	return events.APIGatewayProxyResponse{
		StatusCode: 201,
		Headers:    headers,
		Body:       string(responseBody),
	}, nil
}

// validateCreateItemRequest validates the create item request
func validateCreateItemRequest(req CreateItemRequest) []ValidationError {
	var errors []ValidationError

	// Use struct validation
	if err := validate.Struct(req); err != nil {
		for _, err := range err.(validator.ValidationErrors) {
			field := strings.ToLower(err.Field())
			var message string
			
			switch err.Tag() {
			case "required":
				message = fmt.Sprintf("%s is required", field)
			case "min":
				message = fmt.Sprintf("%s must be at least %s characters long", field, err.Param())
			case "max":
				message = fmt.Sprintf("%s must not exceed %s characters", field, err.Param())
			case "gt":
				message = fmt.Sprintf("%s must be greater than %s", field, err.Param())
			case "oneof":
				message = fmt.Sprintf("%s must be one of: electronics, clothing, books, home, sports, other", field)
			default:
				message = fmt.Sprintf("%s is invalid", field)
			}
			
			errors = append(errors, ValidationError{
				Field:   field,
				Message: message,
				Value:   err.Value(),
			})
		}
	}

	return errors
}

// sanitizeCreateItemRequest sanitizes input data
func sanitizeCreateItemRequest(req CreateItemRequest) CreateItemRequest {
	sanitized := CreateItemRequest{
		Name:     strings.TrimSpace(req.Name),
		Category: strings.TrimSpace(req.Category),
		Price:    req.Price,
	}
	
	if req.Description != nil {
		desc := strings.TrimSpace(*req.Description)
		sanitized.Description = &desc
	}
	
	return sanitized
}

// createItemInDynamoDB creates an item in DynamoDB
func createItemInDynamoDB(ctx context.Context, req CreateItemRequest, requestID string) (*Item, error) {
	// Generate UUID and timestamps
	id := uuid.New().String()
	timestamp := time.Now().UTC().Format(time.RFC3339)

	// Create item
	item := &Item{
		ID:          id,
		Name:        req.Name,
		Description: req.Description,
		Category:    req.Category,
		Price:       req.Price,
		CreatedAt:   timestamp,
		UpdatedAt:   timestamp,
	}

	// Convert to DynamoDB attribute values
	av, err := dynamodbattribute.MarshalMap(item)
	if err != nil {
		return nil, fmt.Errorf("failed to marshal item: %w", err)
	}

	// Put item in DynamoDB
	input := &dynamodb.PutItemInput{
		TableName:           aws.String(tableName),
		Item:                av,
		ConditionExpression: aws.String("attribute_not_exists(id)"),
	}

	startTime := time.Now()
	_, err = dynamoClient.PutItemWithContext(ctx, input)
	duration := time.Since(startTime)

	if err != nil {
		log.Printf("[%s] DynamoDB PutItem failed (duration: %v): %v", requestID, duration, err)
		
		// Check for conditional check failed (duplicate ID)
		if awsErr, ok := err.(awserr.Error); ok {
			if awsErr.Code() == dynamodb.ErrCodeConditionalCheckFailedException {
				return nil, fmt.Errorf("item with ID already exists")
			}
		}
		
		return nil, fmt.Errorf("failed to put item: %w", err)
	}

	log.Printf("[%s] DynamoDB PutItem succeeded (duration: %v)", requestID, duration)
	return item, nil
}

// createErrorResponse creates a standardized error response
func createErrorResponse(statusCode int, message string, details []ValidationError, requestID string, headers map[string]string) events.APIGatewayProxyResponse {
	errorResp := ErrorResponse{
		Error:     getErrorType(statusCode),
		Message:   message,
		Details:   details,
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
	case 409:
		return "Conflict"
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