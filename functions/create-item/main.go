package main

import (
	"context"
	"encoding/json"
	"log"

	"github.com/aws/aws-lambda-go/events"
	"github.com/aws/aws-lambda-go/lambda"
)

// CreateItemRequest represents the request payload for creating an item
type CreateItemRequest struct {
	Name        string  `json:"name" validate:"required,min=1,max=100"`
	Description string  `json:"description,omitempty" validate:"max=500"`
	Category    string  `json:"category" validate:"required"`
	Price       float64 `json:"price" validate:"required,gt=0"`
}

// HandleRequest handles the Lambda function request
func HandleRequest(ctx context.Context, request events.APIGatewayProxyRequest) (events.APIGatewayProxyResponse, error) {
	log.Printf("Received request: %+v", request)

	// TODO: Implement create item logic
	response := events.APIGatewayProxyResponse{
		StatusCode: 501,
		Headers: map[string]string{
			"Content-Type": "application/json",
		},
		Body: `{"message": "Create item function not implemented yet"}`,
	}

	return response, nil
}

func main() {
	lambda.Start(HandleRequest)
}