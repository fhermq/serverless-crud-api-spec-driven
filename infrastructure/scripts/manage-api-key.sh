#!/bin/bash

# Manage API Keys for the Serverless CRUD API
# This script helps create, retrieve, and manage API keys

set -e

# Default values
STAGE="dev"
REGION="us-east-1"
PROJECT_NAME="serverless-crud-api"
ACTION=""
API_KEY_NAME=""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to show usage
show_usage() {
    echo "Usage: $0 ACTION [OPTIONS]"
    echo ""
    echo "Actions:"
    echo "  get-key                     Retrieve the API key value"
    echo "  create-key                  Create a new API key"
    echo "  enable-auth                 Enable API key authentication"
    echo "  disable-auth                Disable API key authentication"
    echo "  get-usage                   Get API usage statistics"
    echo ""
    echo "Options:"
    echo "  --stage STAGE               Deployment stage (default: dev)"
    echo "  --region REGION             AWS region (default: us-east-1)"
    echo "  --project-name NAME         Project name (default: serverless-crud-api)"
    echo "  --api-key-name NAME         Custom API key name (optional)"
    echo "  --help                      Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 get-key"
    echo "  $0 enable-auth --stage prod"
    echo "  $0 create-key --api-key-name my-custom-key"
    echo "  $0 get-usage --stage prod"
}

# Parse command line arguments
if [[ $# -eq 0 ]]; then
    show_usage
    exit 1
fi

ACTION="$1"
shift

while [[ $# -gt 0 ]]; do
    case $1 in
        --stage)
            STAGE="$2"
            shift 2
            ;;
        --region)
            REGION="$2"
            shift 2
            ;;
        --project-name)
            PROJECT_NAME="$2"
            shift 2
            ;;
        --api-key-name)
            API_KEY_NAME="$2"
            shift 2
            ;;
        --help)
            show_usage
            exit 0
            ;;
        *)
            print_error "Unknown option: $1"
            show_usage
            exit 1
            ;;
    esac
done

# Check if AWS CLI is configured
if ! aws sts get-caller-identity &>/dev/null; then
    print_error "AWS CLI is not configured or credentials are invalid"
    print_error "Please run 'aws configure' or set up your AWS credentials"
    exit 1
fi

# Stack names
API_STACK_NAME="${PROJECT_NAME}-${STAGE}-api"

# Function to get API key value
get_api_key() {
    print_status "Retrieving API key for stage: $STAGE"
    
    # Get API key ID from stack outputs
    API_KEY_ID=$(aws cloudformation describe-stacks \
        --stack-name "$API_STACK_NAME" \
        --region "$REGION" \
        --query 'Stacks[0].Outputs[?OutputKey==`ApiKeyId`].OutputValue' \
        --output text 2>/dev/null || echo "")
    
    if [[ -z "$API_KEY_ID" || "$API_KEY_ID" == "None" ]]; then
        print_error "API key not found. API key authentication may not be enabled."
        print_status "To enable API key authentication, run:"
        echo "  $0 enable-auth --stage $STAGE"
        exit 1
    fi
    
    # Get API key value
    API_KEY_VALUE=$(aws apigateway get-api-key \
        --api-key "$API_KEY_ID" \
        --include-value \
        --region "$REGION" \
        --query 'value' \
        --output text 2>/dev/null || echo "")
    
    if [[ -n "$API_KEY_VALUE" ]]; then
        print_success "API Key retrieved successfully"
        echo ""
        echo "API Key ID: $API_KEY_ID"
        echo "API Key Value: $API_KEY_VALUE"
        echo ""
        print_status "Usage instructions:"
        echo "Include the API key in your requests using the X-API-Key header:"
        echo "  curl -H 'X-API-Key: $API_KEY_VALUE' https://your-api-url/items"
        echo ""
        print_warning "Keep this API key secure and do not share it publicly"
    else
        print_error "Could not retrieve API key value"
        exit 1
    fi
}

# Function to enable API key authentication
enable_auth() {
    print_status "Enabling API key authentication for stage: $STAGE"
    
    # Check if stack exists
    if ! aws cloudformation describe-stacks --stack-name "$API_STACK_NAME" --region "$REGION" &>/dev/null; then
        print_error "API stack '$API_STACK_NAME' does not exist"
        print_error "Please deploy the API stack first"
        exit 1
    fi
    
    # Get the directory of this script
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    INFRASTRUCTURE_DIR="$(dirname "$SCRIPT_DIR")"
    
    # Update stack with API key authentication enabled
    PARAMETERS="ParameterKey=FoundationStackName,ParameterValue=${PROJECT_NAME}-${STAGE}-foundation ParameterKey=EnableApiKeyAuth,ParameterValue=true"
    
    if [[ -n "$API_KEY_NAME" ]]; then
        PARAMETERS="$PARAMETERS ParameterKey=ApiKeyName,ParameterValue=$API_KEY_NAME"
    fi
    
    aws cloudformation update-stack \
        --stack-name "$API_STACK_NAME" \
        --template-body "file://${INFRASTRUCTURE_DIR}/stacks/02-api-and-functions.yaml" \
        --parameters $PARAMETERS \
        --capabilities CAPABILITY_IAM \
        --region "$REGION"
    
    print_status "Waiting for stack update to complete..."
    aws cloudformation wait stack-update-complete \
        --stack-name "$API_STACK_NAME" \
        --region "$REGION"
    
    print_success "API key authentication enabled successfully"
    
    # Automatically retrieve the API key
    echo ""
    get_api_key
}

# Function to disable API key authentication
disable_auth() {
    print_status "Disabling API key authentication for stage: $STAGE"
    
    # Check if stack exists
    if ! aws cloudformation describe-stacks --stack-name "$API_STACK_NAME" --region "$REGION" &>/dev/null; then
        print_error "API stack '$API_STACK_NAME' does not exist"
        exit 1
    fi
    
    # Get the directory of this script
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    INFRASTRUCTURE_DIR="$(dirname "$SCRIPT_DIR")"
    
    # Update stack with API key authentication disabled
    aws cloudformation update-stack \
        --stack-name "$API_STACK_NAME" \
        --template-body "file://${INFRASTRUCTURE_DIR}/stacks/02-api-and-functions.yaml" \
        --parameters \
            ParameterKey=FoundationStackName,ParameterValue="${PROJECT_NAME}-${STAGE}-foundation" \
            ParameterKey=EnableApiKeyAuth,ParameterValue=false \
        --capabilities CAPABILITY_IAM \
        --region "$REGION"
    
    print_status "Waiting for stack update to complete..."
    aws cloudformation wait stack-update-complete \
        --stack-name "$API_STACK_NAME" \
        --region "$REGION"
    
    print_success "API key authentication disabled successfully"
    print_warning "The API is now publicly accessible without authentication"
}

# Function to get API usage statistics
get_usage() {
    print_status "Retrieving API usage statistics for stage: $STAGE"
    
    # Get usage plan ID from stack outputs
    USAGE_PLAN_ID=$(aws cloudformation describe-stacks \
        --stack-name "$API_STACK_NAME" \
        --region "$REGION" \
        --query 'Stacks[0].Outputs[?OutputKey==`ApiUsagePlanId`].OutputValue' \
        --output text 2>/dev/null || echo "")
    
    if [[ -z "$USAGE_PLAN_ID" || "$USAGE_PLAN_ID" == "None" ]]; then
        print_error "Usage plan not found. API key authentication may not be enabled."
        exit 1
    fi
    
    # Get API key ID
    API_KEY_ID=$(aws cloudformation describe-stacks \
        --stack-name "$API_STACK_NAME" \
        --region "$REGION" \
        --query 'Stacks[0].Outputs[?OutputKey==`ApiKeyId`].OutputValue' \
        --output text 2>/dev/null || echo "")
    
    if [[ -z "$API_KEY_ID" || "$API_KEY_ID" == "None" ]]; then
        print_error "API key not found"
        exit 1
    fi
    
    # Get current date for usage query
    END_DATE=$(date -u +"%Y-%m-%d")
    START_DATE=$(date -u -d "30 days ago" +"%Y-%m-%d")
    
    print_status "Usage statistics from $START_DATE to $END_DATE:"
    
    # Get usage data
    aws apigateway get-usage \
        --usage-plan-id "$USAGE_PLAN_ID" \
        --key-id "$API_KEY_ID" \
        --start-date "$START_DATE" \
        --end-date "$END_DATE" \
        --region "$REGION" \
        --query '{
            UsagePlanId: usagePlanId,
            StartDate: startDate,
            EndDate: endDate,
            Position: position,
            Items: items
        }' \
        --output table 2>/dev/null || print_warning "No usage data available for the specified period"
    
    # Get usage plan details
    echo ""
    print_status "Usage plan configuration:"
    aws apigateway get-usage-plan \
        --usage-plan-id "$USAGE_PLAN_ID" \
        --region "$REGION" \
        --query '{
            Name: name,
            Description: description,
            ThrottleRateLimit: throttle.rateLimit,
            ThrottleBurstLimit: throttle.burstLimit,
            QuotaLimit: quota.limit,
            QuotaPeriod: quota.period
        }' \
        --output table
}

# Function to create a standalone API key
create_key() {
    print_status "Creating new API key for stage: $STAGE"
    
    # Check if API stack exists and has usage plan
    USAGE_PLAN_ID=$(aws cloudformation describe-stacks \
        --stack-name "$API_STACK_NAME" \
        --region "$REGION" \
        --query 'Stacks[0].Outputs[?OutputKey==`ApiUsagePlanId`].OutputValue' \
        --output text 2>/dev/null || echo "")
    
    if [[ -z "$USAGE_PLAN_ID" || "$USAGE_PLAN_ID" == "None" ]]; then
        print_error "Usage plan not found. Please enable API key authentication first:"
        echo "  $0 enable-auth --stage $STAGE"
        exit 1
    fi
    
    # Generate API key name if not provided
    if [[ -z "$API_KEY_NAME" ]]; then
        API_KEY_NAME="${PROJECT_NAME}-${STAGE}-additional-key-$(date +%s)"
    fi
    
    # Create API key
    API_KEY_RESPONSE=$(aws apigateway create-api-key \
        --name "$API_KEY_NAME" \
        --description "Additional API key for ${PROJECT_NAME} ${STAGE}" \
        --enabled \
        --region "$REGION" \
        --output json)
    
    NEW_API_KEY_ID=$(echo "$API_KEY_RESPONSE" | jq -r '.id')
    NEW_API_KEY_VALUE=$(echo "$API_KEY_RESPONSE" | jq -r '.value')
    
    # Associate with usage plan
    aws apigateway create-usage-plan-key \
        --usage-plan-id "$USAGE_PLAN_ID" \
        --key-id "$NEW_API_KEY_ID" \
        --key-type API_KEY \
        --region "$REGION" &>/dev/null
    
    print_success "New API key created successfully"
    echo ""
    echo "API Key ID: $NEW_API_KEY_ID"
    echo "API Key Value: $NEW_API_KEY_VALUE"
    echo ""
    print_status "This key is now associated with the usage plan and ready to use"
    print_warning "Keep this API key secure and do not share it publicly"
}

# Execute the requested action
case $ACTION in
    get-key)
        get_api_key
        ;;
    enable-auth)
        enable_auth
        ;;
    disable-auth)
        disable_auth
        ;;
    get-usage)
        get_usage
        ;;
    create-key)
        create_key
        ;;
    *)
        print_error "Unknown action: $ACTION"
        show_usage
        exit 1
        ;;
esac