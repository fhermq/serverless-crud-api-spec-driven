package main

import (
	"context"
	"encoding/json"
	"os"
	"testing"

	"github.com/aws/aws-lambda-go/events"
	validator "github.com/go-playground/validator/v10"
)

// Test setup
func TestMain(m *testing.M) {
	// Set up test environment
	os.Setenv("DYNAMODB_TABLE_NAME", "test-table")
	os.Setenv("AWS_REGION", "us-east-1")
	
	// Initialize test validator
	validate = validator.New()
	
	// Run tests
	code := m.Run()
	
	// Clean up
	os.Exit(code)
}

func TestValidateCreateItemRequest(t *testing.T) {
	tests := []struct {
		name          string
		request       CreateItemRequest
		expectedErrors int
	}{
		{
			name: "Valid request",
			request: CreateItemRequest{
				Name:     "Test Item",
				Category: "electronics",
				Price:    29.99,
			},
			expectedErrors: 0,
		},
		{
			name: "Valid request with description",
			request: CreateItemRequest{
				Name:        "Test Item",
				Description: stringPtr("A test item description"),
				Category:    "books",
				Price:       15.50,
			},
			expectedErrors: 0,
		},
		{
			name: "Missing name",
			request: CreateItemRequest{
				Category: "electronics",
				Price:    29.99,
			},
			expectedErrors: 1,
		},
		{
			name: "Empty name",
			request: CreateItemRequest{
				Name:     "",
				Category: "electronics",
				Price:    29.99,
			},
			expectedErrors: 1,
		},
		{
			name: "Name too long",
			request: CreateItemRequest{
				Name:     "This is a very long name that exceeds the maximum allowed length of 100 characters for item names in our system",
				Category: "electronics",
				Price:    29.99,
			},
			expectedErrors: 1,
		},
		{
			name: "Missing category",
			request: CreateItemRequest{
				Name:  "Test Item",
				Price: 29.99,
			},
			expectedErrors: 1,
		},
		{
			name: "Invalid category",
			request: CreateItemRequest{
				Name:     "Test Item",
				Category: "invalid-category",
				Price:    29.99,
			},
			expectedErrors: 1,
		},
		{
			name: "Missing price",
			request: CreateItemRequest{
				Name:     "Test Item",
				Category: "electronics",
			},
			expectedErrors: 1,
		},
		{
			name: "Zero price",
			request: CreateItemRequest{
				Name:     "Test Item",
				Category: "electronics",
				Price:    0,
			},
			expectedErrors: 1,
		},
		{
			name: "Negative price",
			request: CreateItemRequest{
				Name:     "Test Item",
				Category: "electronics",
				Price:    -10.50,
			},
			expectedErrors: 1,
		},
		{
			name: "Description too long",
			request: CreateItemRequest{
				Name:        "Test Item",
				Description: stringPtr("This is a very long description that exceeds the maximum allowed length of 500 characters. Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum. Sed ut perspiciatis unde omnis iste natus error sit voluptatem accusantium doloremque laudantium."),
				Category:    "electronics",
				Price:       29.99,
			},
			expectedErrors: 1,
		},
		{
			name: "Multiple validation errors",
			request: CreateItemRequest{
				Name:     "",
				Category: "invalid",
				Price:    -5,
			},
			expectedErrors: 3,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			errors := validateCreateItemRequest(tt.request)
			if len(errors) != tt.expectedErrors {
				t.Errorf("Expected %d validation errors, got %d. Errors: %+v", tt.expectedErrors, len(errors), errors)
			}
		})
	}
}

func TestSanitizeCreateItemRequest(t *testing.T) {
	tests := []struct {
		name     string
		input    CreateItemRequest
		expected CreateItemRequest
	}{
		{
			name: "Trim whitespace from name and category",
			input: CreateItemRequest{
				Name:     "  Test Item  ",
				Category: "  electronics  ",
				Price:    29.99,
			},
			expected: CreateItemRequest{
				Name:     "Test Item",
				Category: "electronics",
				Price:    29.99,
			},
		},
		{
			name: "Trim whitespace from description",
			input: CreateItemRequest{
				Name:        "Test Item",
				Description: stringPtr("  Test description  "),
				Category:    "books",
				Price:       15.50,
			},
			expected: CreateItemRequest{
				Name:        "Test Item",
				Description: stringPtr("Test description"),
				Category:    "books",
				Price:       15.50,
			},
		},
		{
			name: "No changes needed",
			input: CreateItemRequest{
				Name:     "Test Item",
				Category: "electronics",
				Price:    29.99,
			},
			expected: CreateItemRequest{
				Name:     "Test Item",
				Category: "electronics",
				Price:    29.99,
			},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			result := sanitizeCreateItemRequest(tt.input)
			
			if result.Name != tt.expected.Name {
				t.Errorf("Expected name '%s', got '%s'", tt.expected.Name, result.Name)
			}
			if result.Category != tt.expected.Category {
				t.Errorf("Expected category '%s', got '%s'", tt.expected.Category, result.Category)
			}
			if result.Price != tt.expected.Price {
				t.Errorf("Expected price %f, got %f", tt.expected.Price, result.Price)
			}
			
			if tt.expected.Description == nil && result.Description != nil {
				t.Errorf("Expected description to be nil, got '%s'", *result.Description)
			} else if tt.expected.Description != nil && result.Description == nil {
				t.Errorf("Expected description '%s', got nil", *tt.expected.Description)
			} else if tt.expected.Description != nil && result.Description != nil && *result.Description != *tt.expected.Description {
				t.Errorf("Expected description '%s', got '%s'", *tt.expected.Description, *result.Description)
			}
		})
	}
}

func TestHandleRequest_ValidationErrors(t *testing.T) {
	tests := []struct {
		name           string
		requestBody    string
		expectedStatus int
		expectedError  string
	}{
		{
			name:           "Invalid JSON",
			requestBody:    `{"name": "Test", "price": }`,
			expectedStatus: 400,
			expectedError:  "Invalid JSON format",
		},
		{
			name:           "Missing required fields",
			requestBody:    `{"name": ""}`,
			expectedStatus: 400,
			expectedError:  "Validation failed",
		},
		{
			name:           "Invalid category",
			requestBody:    `{"name": "Test", "category": "invalid", "price": 10}`,
			expectedStatus: 400,
			expectedError:  "Validation failed",
		},
		{
			name:           "Negative price",
			requestBody:    `{"name": "Test", "category": "electronics", "price": -5}`,
			expectedStatus: 400,
			expectedError:  "Validation failed",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Create test request
			request := events.APIGatewayProxyRequest{
				HTTPMethod: "POST",
				Body:       tt.requestBody,
			}

			// Call handler
			response, err := HandleRequest(context.Background(), request)

			// Check for unexpected errors
			if err != nil {
				t.Errorf("Unexpected error: %v", err)
			}

			// Check status code
			if response.StatusCode != tt.expectedStatus {
				t.Errorf("Expected status %d, got %d", tt.expectedStatus, response.StatusCode)
			}

			// Parse response body
			var errorResp ErrorResponse
			if err := json.Unmarshal([]byte(response.Body), &errorResp); err != nil {
				t.Errorf("Failed to parse error response: %v", err)
			}

			// Check error message
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

	// Check CORS headers
	expectedHeaders := map[string]string{
		"Access-Control-Allow-Origin":  "*",
		"Access-Control-Allow-Methods": "POST, OPTIONS",
		"Access-Control-Allow-Headers": "Content-Type, Authorization",
	}

	for key, expectedValue := range expectedHeaders {
		if actualValue, exists := response.Headers[key]; !exists || actualValue != expectedValue {
			t.Errorf("Expected header %s: %s, got %s", key, expectedValue, actualValue)
		}
	}
}

func TestGetErrorType(t *testing.T) {
	tests := []struct {
		statusCode   int
		expectedType string
	}{
		{400, "BadRequest"},
		{404, "NotFound"},
		{409, "Conflict"},
		{500, "InternalServerError"},
		{503, "Error"},
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
}

// Mock DynamoDB tests would require more complex setup with AWS SDK mocking
// For now, we focus on the business logic validation and request handling

// Helper function to create string pointer
func stringPtr(s string) *string {
	return &s
}

// Benchmark tests
func BenchmarkValidateCreateItemRequest(b *testing.B) {
	req := CreateItemRequest{
		Name:        "Test Item",
		Description: stringPtr("Test description"),
		Category:    "electronics",
		Price:       29.99,
	}

	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		validateCreateItemRequest(req)
	}
}

func BenchmarkSanitizeCreateItemRequest(b *testing.B) {
	req := CreateItemRequest{
		Name:        "  Test Item  ",
		Description: stringPtr("  Test description  "),
		Category:    "  electronics  ",
		Price:       29.99,
	}

	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		sanitizeCreateItemRequest(req)
	}
}