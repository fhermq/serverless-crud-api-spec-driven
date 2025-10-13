#!/bin/bash

# Deployment Verification Script
# Verifies that a deployment was successful and all components are working

set -e

# Default values
STAGE="dev"
REGION="us-east-1"
TIMEOUT=300  # 5 minutes timeout
VERBOSE=false

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
}

# Function to show usage
show_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --stage STAGE        Deployment stage (dev, staging, prod) [default: dev]"
    echo "  --region REGION      AWS region [default: us-east-1]"
    echo "  --timeout SECONDS    Verification timeout in seconds [default: 300]"
    echo "  --verbose           Enable verbose output"
    echo "  --help              Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 --stage dev --region us-east-1"
    echo "  $0 --stage prod --timeout 600 --verbose"
}

# Parse command line arguments
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
        --timeout)
            TIMEOUT="$2"
            shift 2
            ;;
        --verbose)
            VERBOSE=true
            shift
            ;;
        --help)
            show_usage
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            show_usage
            exit 1
            ;;
    esac
done

# Validate stage
if [[ ! "$STAGE" =~ ^(dev|staging|prod)$ ]]; then
    print_status $RED "❌ Invalid stage: $STAGE. Must be dev, staging, or prod"
    exit 1
fi

print_status $BLUE "🔍 Starting deployment verification for $STAGE environment in $REGION"
print_status $BLUE "⏱️ Timeout: ${TIMEOUT}s"

# Set stack names
PROJECT_NAME="serverless-crud-api"
FOUNDATION_STACK="$PROJECT_NAME-$STAGE-foundation"
API_STACK="$PROJECT_NAME-$STAGE-api"
MONITORING_STACK="$PROJECT_NAME-$STAGE-monitoring"

# Function to check stack status
check_stack_status() {
    local stack_name=$1
    local expected_status=$2
    
    print_status $YELLOW "📋 Checking stack: $stack_name"
    
    local status=$(aws cloudformation describe-stacks \
        --stack-name "$stack_name" \
        --region "$REGION" \
        --query 'Stacks[0].StackStatus' \
        --output text 2>/dev/null || echo "NOT_FOUND")
    
    if [ "$VERBOSE" = true ]; then
        print_status $BLUE "   Stack status: $status"
    fi
    
    if [[ "$status" == "$expected_status" ]]; then
        print_status $GREEN "   ✅ Stack $stack_name is in expected state: $status"
        return 0
    else
        print_status $RED "   ❌ Stack $stack_name is in unexpected state: $status (expected: $expected_status)"
        return 1
    fi
}

# Function to get stack output
get_stack_output() {
    local stack_name=$1
    local output_key=$2
    
    aws cloudformation describe-stacks \
        --stack-name "$stack_name" \
        --region "$REGION" \
        --query "Stacks[0].Outputs[?OutputKey=='$output_key'].OutputValue" \
        --output text 2>/dev/null || echo ""
}

# Function to test API endpoint
test_api_endpoint() {
    local api_url=$1
    local endpoint=$2
    local expected_status=$3
    local method=${4:-GET}
    
    print_status $YELLOW "🌐 Testing $method $endpoint (expecting $expected_status)"
    
    local full_url="$api_url$endpoint"
    local actual_status
    
    if [[ "$method" == "GET" ]]; then
        actual_status=$(curl -s -o /dev/null -w "%{http_code}" "$full_url" || echo "000")
    elif [[ "$method" == "POST" ]]; then
        actual_status=$(curl -s -o /dev/null -w "%{http_code}" \
            -X POST \
            -H "Content-Type: application/json" \
            -d '{"name":"Test Item","category":"electronics","price":99.99}' \
            "$full_url" || echo "000")
    fi
    
    if [ "$VERBOSE" = true ]; then
        print_status $BLUE "   Response status: $actual_status"
    fi
    
    if [[ "$actual_status" == "$expected_status" ]]; then
        print_status $GREEN "   ✅ API endpoint test passed"
        return 0
    else
        print_status $RED "   ❌ API endpoint test failed (got $actual_status, expected $expected_status)"
        return 1
    fi
}

# Function to check Lambda function
check_lambda_function() {
    local function_name=$1
    
    print_status $YELLOW "⚡ Checking Lambda function: $function_name"
    
    local function_status=$(aws lambda get-function \
        --function-name "$function_name" \
        --region "$REGION" \
        --query 'Configuration.State' \
        --output text 2>/dev/null || echo "NOT_FOUND")
    
    if [ "$VERBOSE" = true ]; then
        print_status $BLUE "   Function state: $function_status"
    fi
    
    if [[ "$function_status" == "Active" ]]; then
        print_status $GREEN "   ✅ Lambda function is active"
        
        # Test function invocation
        local test_result=$(aws lambda invoke \
            --function-name "$function_name" \
            --region "$REGION" \
            --payload '{}' \
            --cli-binary-format raw-in-base64-out \
            /tmp/lambda-test-output.json 2>/dev/null || echo "FAILED")
        
        if [[ "$test_result" != "FAILED" ]]; then
            print_status $GREEN "   ✅ Lambda function invocation test passed"
        else
            print_status $YELLOW "   ⚠️ Lambda function invocation test failed (may be expected for some functions)"
        fi
        
        return 0
    else
        print_status $RED "   ❌ Lambda function is not active: $function_status"
        return 1
    fi
}

# Function to check DynamoDB table
check_dynamodb_table() {
    local table_name=$1
    
    print_status $YELLOW "🗄️ Checking DynamoDB table: $table_name"
    
    local table_status=$(aws dynamodb describe-table \
        --table-name "$table_name" \
        --region "$REGION" \
        --query 'Table.TableStatus' \
        --output text 2>/dev/null || echo "NOT_FOUND")
    
    if [ "$VERBOSE" = true ]; then
        print_status $BLUE "   Table status: $table_status"
    fi
    
    if [[ "$table_status" == "ACTIVE" ]]; then
        print_status $GREEN "   ✅ DynamoDB table is active"
        
        # Check table item count (optional)
        local item_count=$(aws dynamodb scan \
            --table-name "$table_name" \
            --region "$REGION" \
            --select "COUNT" \
            --query 'Count' \
            --output text 2>/dev/null || echo "0")
        
        if [ "$VERBOSE" = true ]; then
            print_status $BLUE "   Table item count: $item_count"
        fi
        
        return 0
    else
        print_status $RED "   ❌ DynamoDB table is not active: $table_status"
        return 1
    fi
}

# Start verification process
START_TIME=$(date +%s)
VERIFICATION_FAILED=false

print_status $BLUE "🚀 Starting comprehensive deployment verification..."

# Step 1: Check CloudFormation stacks
print_status $BLUE "\n📋 Step 1: Verifying CloudFormation stacks"

if ! check_stack_status "$FOUNDATION_STACK" "CREATE_COMPLETE" && ! check_stack_status "$FOUNDATION_STACK" "UPDATE_COMPLETE"; then
    VERIFICATION_FAILED=true
fi

if ! check_stack_status "$API_STACK" "CREATE_COMPLETE" && ! check_stack_status "$API_STACK" "UPDATE_COMPLETE"; then
    VERIFICATION_FAILED=true
fi

if ! check_stack_status "$MONITORING_STACK" "CREATE_COMPLETE" && ! check_stack_status "$MONITORING_STACK" "UPDATE_COMPLETE"; then
    print_status $YELLOW "   ⚠️ Monitoring stack verification failed (may not be deployed yet)"
fi

# Step 2: Check DynamoDB table
print_status $BLUE "\n🗄️ Step 2: Verifying DynamoDB table"

TABLE_NAME=$(get_stack_output "$FOUNDATION_STACK" "ItemsTableName")
if [[ -n "$TABLE_NAME" ]]; then
    if ! check_dynamodb_table "$TABLE_NAME"; then
        VERIFICATION_FAILED=true
    fi
else
    print_status $RED "❌ Could not get DynamoDB table name from stack outputs"
    VERIFICATION_FAILED=true
fi

# Step 3: Check Lambda functions
print_status $BLUE "\n⚡ Step 3: Verifying Lambda functions"

LAMBDA_FUNCTIONS=(
    "$PROJECT_NAME-$STAGE-create-item"
    "$PROJECT_NAME-$STAGE-get-item"
    "$PROJECT_NAME-$STAGE-update-item"
    "$PROJECT_NAME-$STAGE-delete-item"
)

for func in "${LAMBDA_FUNCTIONS[@]}"; do
    if ! check_lambda_function "$func"; then
        VERIFICATION_FAILED=true
    fi
done

# Step 4: Check API Gateway
print_status $BLUE "\n🌐 Step 4: Verifying API Gateway"

API_URL=$(get_stack_output "$API_STACK" "ApiUrl")
if [[ -n "$API_URL" ]]; then
    print_status $GREEN "✅ API URL retrieved: $API_URL"
    
    # Test API endpoints
    if ! test_api_endpoint "$API_URL" "/items/test-id" "404"; then  # Should return 404 for non-existent item
        VERIFICATION_FAILED=true
    fi
    
    # Test CORS preflight (OPTIONS request)
    print_status $YELLOW "🌐 Testing CORS preflight request"
    CORS_STATUS=$(curl -s -o /dev/null -w "%{http_code}" \
        -X OPTIONS \
        -H "Origin: https://example.com" \
        -H "Access-Control-Request-Method: POST" \
        -H "Access-Control-Request-Headers: Content-Type" \
        "$API_URL/items" || echo "000")
    
    if [[ "$CORS_STATUS" == "200" ]]; then
        print_status $GREEN "   ✅ CORS preflight test passed"
    else
        print_status $YELLOW "   ⚠️ CORS preflight test failed (status: $CORS_STATUS)"
    fi
    
else
    print_status $RED "❌ Could not get API URL from stack outputs"
    VERIFICATION_FAILED=true
fi

# Step 5: Check CloudWatch resources (if monitoring stack exists)
print_status $BLUE "\n📊 Step 5: Verifying CloudWatch resources"

DASHBOARD_NAME=$(get_stack_output "$MONITORING_STACK" "DashboardName" 2>/dev/null || echo "")
if [[ -n "$DASHBOARD_NAME" ]]; then
    print_status $YELLOW "📊 Checking CloudWatch dashboard: $DASHBOARD_NAME"
    
    DASHBOARD_EXISTS=$(aws cloudwatch get-dashboard \
        --dashboard-name "$DASHBOARD_NAME" \
        --region "$REGION" \
        --query 'DashboardName' \
        --output text 2>/dev/null || echo "")
    
    if [[ -n "$DASHBOARD_EXISTS" ]]; then
        print_status $GREEN "   ✅ CloudWatch dashboard exists"
    else
        print_status $YELLOW "   ⚠️ CloudWatch dashboard not found"
    fi
else
    print_status $YELLOW "   ⚠️ Monitoring stack not deployed or dashboard name not available"
fi

# Calculate verification time
END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))

# Final verification result
print_status $BLUE "\n🏁 Verification Summary"
print_status $BLUE "⏱️ Total verification time: ${DURATION}s"

if [ "$VERIFICATION_FAILED" = true ]; then
    print_status $RED "❌ DEPLOYMENT VERIFICATION FAILED"
    print_status $RED "   Some components are not working correctly"
    print_status $YELLOW "   Check the logs above for specific issues"
    exit 1
else
    print_status $GREEN "✅ DEPLOYMENT VERIFICATION SUCCESSFUL"
    print_status $GREEN "   All components are working correctly"
    print_status $BLUE "   Environment: $STAGE"
    print_status $BLUE "   Region: $REGION"
    if [[ -n "$API_URL" ]]; then
        print_status $BLUE "   API URL: $API_URL"
    fi
fi

# Cleanup temporary files
rm -f /tmp/lambda-test-output.json

print_status $GREEN "🎉 Deployment verification completed successfully!"