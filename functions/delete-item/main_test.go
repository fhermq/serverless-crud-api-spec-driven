package main

import (
	"context"
	"testing"

	"github.com/aws/aws-lambda-go/events"
)

func TestHandleRequest(t *testing.T) {
	// Test that the function returns 501 Not Implemented
	ctx := context.Background()
	request := events.APIGatewayProxyRequest{
		HTTPMethod: "DELETE",
		Path:       "/items/test-id",
	}

	response, err := HandleRequest(ctx, request)

	if err != nil {
		t.Errorf("Expected no error, got %v", err)
	}

	if response.StatusCode != 501 {
		t.Errorf("Expected status code 501, got %d", response.StatusCode)
	}

	expectedBody := `{"message": "Delete item function not implemented yet"}`
	if response.Body != expectedBody {
		t.Errorf("Expected body %s, got %s", expectedBody, response.Body)
	}

	// Check headers
	if response.Headers["Content-Type"] != "application/json" {
		t.Errorf("Expected Content-Type header to be application/json, got %s", response.Headers["Content-Type"])
	}
}

func TestHandleRequestWithDifferentMethods(t *testing.T) {
	// Test that the function handles different HTTP methods consistently
	ctx := context.Background()
	
	methods := []string{"GET", "POST", "PUT", "PATCH"}
	
	for _, method := range methods {
		request := events.APIGatewayProxyRequest{
			HTTPMethod: method,
			Path:       "/items/test-id",
		}

		response, err := HandleRequest(ctx, request)

		if err != nil {
			t.Errorf("Expected no error for method %s, got %v", method, err)
		}

		if response.StatusCode != 501 {
			t.Errorf("Expected status code 501 for method %s, got %d", method, response.StatusCode)
		}
	}
}