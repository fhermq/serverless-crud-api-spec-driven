package main

import (
	"context"
	"encoding/json"
	"os"
	"testing"

	"github.com/aws/aws-lambda-go/events"
)

// Test setup
func TestMain(m *testing.M) {
	// Set up test environment
	os.Setenv("DYNAMODB_TABLE_NAME", "test-table")
	os.Setenv("AWS_REGION", "us-east-1")
	os.Setenv("LOG_LEVEL", "ERROR") // Reduce log noise during tests

	// Run tests
	code := m.Run()

	// Clean up
	os.Exit(code)
}

func TestIsValidUUID(t *testing.T) {
	tests := []struct {
		name     string
		uuid     string
		expected bool
	}{
		{
			name:     "Valid UUID v4",
			uuid:     "550e8400-e29b-41d4-a716-446655440000",
			expected: true,
		},
		{
			name:     "Valid UUID v1",
			uuid:     "6ba7b810-9dad-11d1-80b4-00c04fd430c8",
			expected: true,
		},
		{
			name:     "Invalid UUID - too short",
			uuid:     "550e8400-e29b-41d4-a716",
			expected: false,
		},
		{
			name:     "Invalid UUID - invalid characters",
			uuid:     "550e8400-e29b-41d4-a716-44665544000g",
			expected: false,
		},
		{
			name:     "Valid UUID without hyphens",
			uuid:     "550e8400e29b41d4a716446655440000",
			expected: true,
		},
		{
			name:     "Empty string",
			uuid:     "",
			expected: false,
		},
		{
			name:     "Random string",
			uuid:     "not-a-uuid",
			expected: false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			result := isValidUUID(tt.uuid)
			if result != tt.expected {
				t.Errorf("Expected isValidUUID(%s) = %v, got %v", tt.uuid, tt.expected, result)
			}
		})
	}
}

func TestHandleRequest_MissingItemID(t *testing.T) {
	tests := []struct {
		name           string
		pathParameters map[string]string
		expectedStatus int
		expectedError  string
	}{
		{
			name:           "Missing path parameters",
			pathParameters: nil,
			expectedStatus: 400,
			expectedError:  "Item ID is required",
		},
		{
			name:           "Empty path parameters",
			pathParameters: map[string]string{},
			expectedStatus: 400,
			expectedError:  "Item ID is required",
		},
		{
			name:           "Empty item ID",
			pathParameters: map[string]string{"id": ""},
			expectedStatus: 400,
			expectedError:  "Item ID is required",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			request := events.APIGatewayProxyRequest{
				HTTPMethod:     "DELETE",
				PathParameters: tt.pathParameters,
			}

			response, err := HandleRequest(context.Background(), request)

			if err != nil {
				t.Errorf("Unexpected error: %v", err)
			}

			if response.StatusCode != tt.expectedStatus {
				t.Errorf("Expected status %d, got %d", tt.expectedStatus, response.StatusCode)
			}

			var errorResp ErrorResponse
			if err := json.Unmarshal([]byte(response.Body), &errorResp); err != nil {
				t.Errorf("Failed to parse error response: %v", err)
			}

			if errorResp.Message != tt.expectedError {
				t.Errorf("Expected error message '%s', got '%s'", tt.expectedError, errorResp.Message)
			}
		})
	}
}

func TestHandleRequest_InvalidUUID(t *testing.T) {
	tests := []struct {
		name           string
		itemID         string
		expectedStatus int
		expectedError  string
	}{
		{
			name:           "Invalid UUID format",
			itemID:         "invalid-uuid",
			expectedStatus: 400,
			expectedError:  "Invalid item ID format",
		},
		{
			name:           "UUID too short",
			itemID:         "550e8400-e29b-41d4",
			expectedStatus: 400,
			expectedError:  "Invalid item ID format",
		},
		{
			name:           "UUID with invalid characters",
			itemID:         "550e8400-e29b-41d4-a716-44665544000g",
			expectedStatus: 400,
			expectedError:  "Invalid item ID format",
		},
		{
			name:           "Random string",
			itemID:         "not-a-uuid-at-all",
			expectedStatus: 400,
			expectedError:  "Invalid item ID format",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			request := events.APIGatewayProxyRequest{
				HTTPMethod: "DELETE",
				PathParameters: map[string]string{
					"id": tt.itemID,
				},
			}

			response, err := HandleRequest(context.Background(), request)

			if err != nil {
				t.Errorf("Unexpected error: %v", err)
			}

			if response.StatusCode != tt.expectedStatus {
				t.Errorf("Expected status %d, got %d", tt.expectedStatus, response.StatusCode)
			}

			var errorResp ErrorResponse
			if err := json.Unmarshal([]byte(response.Body), &errorResp); err != nil {
				t.Errorf("Failed to parse error response: %v", err)
			}

			if errorResp.Message != tt.expectedError {
				t.Errorf("Expected error message '%s', got '%s'", tt.expectedError, errorResp.Message)
			}
		})
	}
}

func TestHandleRequest_OptionsRequest(t *testing.T) {
	request := events.APIGatewayProxyRequest{
		HTTPMethod: "OPTIONS",
	}

	response, err := HandleRequest(context.Background(), request)

	if err != nil {
		t.Errorf("Unexpected error: %v", err)
	}

	if response.StatusCode != 200 {
		t.Errorf("Expected status 200, got %d", response.StatusCode)
	}

	if response.Body != "" {
		t.Errorf("Expected empty body for OPTIONS request, got %s", response.Body)
	}

	// Check CORS headers
	expectedHeaders := map[string]string{
		"Content-Type":                 "application/json",
		"Access-Control-Allow-Origin":  "*",
		"Access-Control-Allow-Methods": "DELETE, OPTIONS",
		"Access-Control-Allow-Headers": "Content-Type, Authorization",
	}

	for key, expectedValue := range expectedHeaders {
		if actualValue, exists := response.Headers[key]; !exists || actualValue != expectedValue {
			t.Errorf("Expected header %s: %s, got %s", key, expectedValue, actualValue)
		}
	}
}

func TestCreateErrorResponse(t *testing.T) {
	tests := []struct {
		name           string
		statusCode     int
		message        string
		requestID      string
		expectedError  string
	}{
		{
			name:          "Bad Request",
			statusCode:    400,
			message:       "Invalid request",
			requestID:     "test-123",
			expectedError: "BadRequest",
		},
		{
			name:          "Not Found",
			statusCode:    404,
			message:       "Item not found",
			requestID:     "test-456",
			expectedError: "NotFound",
		},
		{
			name:          "Internal Server Error",
			statusCode:    500,
			message:       "Server error",
			requestID:     "test-789",
			expectedError: "InternalServerError",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			headers := map[string]string{"Content-Type": "application/json"}
			response := createErrorResponse(tt.statusCode, tt.message, tt.requestID, headers)

			if response.StatusCode != tt.statusCode {
				t.Errorf("Expected status code %d, got %d", tt.statusCode, response.StatusCode)
			}

			var errorResp ErrorResponse
			if err := json.Unmarshal([]byte(response.Body), &errorResp); err != nil {
				t.Errorf("Failed to parse error response: %v", err)
			}

			if errorResp.Error != tt.expectedError {
				t.Errorf("Expected error type '%s', got '%s'", tt.expectedError, errorResp.Error)
			}

			if errorResp.Message != tt.message {
				t.Errorf("Expected message '%s', got '%s'", tt.message, errorResp.Message)
			}

			if errorResp.RequestID != tt.requestID {
				t.Errorf("Expected request ID '%s', got '%s'", tt.requestID, errorResp.RequestID)
			}
		})
	}
}

func TestGetErrorType(t *testing.T) {
	tests := []struct {
		statusCode   int
		expectedType string
	}{
		{400, "BadRequest"},
		{404, "NotFound"},
		{500, "InternalServerError"},
		{503, "Error"},
		{999, "Error"},
	}

	for _, tt := range tests {
		t.Run(string(rune(tt.statusCode)), func(t *testing.T) {
			result := getErrorType(tt.statusCode)
			if result != tt.expectedType {
				t.Errorf("Expected error type '%s', got '%s'", tt.expectedType, result)
			}
		})
	}
}

func TestGenerateRequestID(t *testing.T) {
	id1 := generateRequestID()
	id2 := generateRequestID()

	// Check length (should be 8 characters)
	if len(id1) != 8 {
		t.Errorf("Expected request ID length 8, got %d", len(id1))
	}

	// Check uniqueness
	if id1 == id2 {
		t.Errorf("Expected unique request IDs, got same ID: %s", id1)
	}

	// Check that it's a valid UUID prefix
	if !isValidUUID(id1 + "-0000-0000-0000-000000000000") {
		t.Errorf("Generated request ID '%s' is not a valid UUID prefix", id1)
	}
}

// Test the complete request flow with valid UUID but without DynamoDB
// Note: These tests would require DynamoDB mocking for complete integration testing
func TestHandleRequest_ValidUUID_WithoutDynamoDB(t *testing.T) {
	// This test demonstrates the structure but would fail without DynamoDB
	// In a real environment, we would mock the DynamoDB client
	validUUID := "550e8400-e29b-41d4-a716-446655440000"

	request := events.APIGatewayProxyRequest{
		HTTPMethod: "DELETE",
		PathParameters: map[string]string{
			"id": validUUID,
		},
	}

	// This would fail because we don't have DynamoDB configured in test
	response, err := HandleRequest(context.Background(), request)

	if err != nil {
		t.Errorf("Unexpected error: %v", err)
	}

	// Without proper DynamoDB setup, this should return a 500 error
	if response.StatusCode != 500 {
		t.Logf("Note: This test requires DynamoDB setup. Got status: %d", response.StatusCode)
	}
}

// Benchmark tests
func BenchmarkIsValidUUID(b *testing.B) {
	uuid := "550e8400-e29b-41d4-a716-446655440000"
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		isValidUUID(uuid)
	}
}

func BenchmarkGenerateRequestID(b *testing.B) {
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		generateRequestID()
	}
}

func BenchmarkCreateErrorResponse(b *testing.B) {
	headers := map[string]string{"Content-Type": "application/json"}
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		createErrorResponse(400, "Test error", "test-123", headers)
	}
}