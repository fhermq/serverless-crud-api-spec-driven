package main

import (
	"context"
	"log"

	"github.com/aws/aws-lambda-go/events"
	"github.com/aws/aws-lambda-go/lambda"
)

// HandleRequest handles the Lambda function request for deleting an item
func HandleRequest(ctx context.Context, request events.APIGatewayProxyRequest) (events.APIGatewayProxyResponse, error) {
	log.Printf("Received request: %+v", request)

	// TODO: Implement delete item logic
	response := events.APIGatewayProxyResponse{
		StatusCode: 501,
		Headers: map[string]string{
			"Content-Type": "application/json",
		},
		Body: `{"message": "Delete item function not implemented yet"}`,
	}

	return response, nil
}

func main() {
	lambda.Start(HandleRequest)
}