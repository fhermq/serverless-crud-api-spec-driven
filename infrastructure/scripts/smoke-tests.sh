#!/bin/bash

# Smoke Tests Script
# Quick validation tests to ensure deployment is working

set -e

# Default values
STAGE="dev"
REGION="us-east-1"
TIMEOUT=60
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
    echo "Quick smoke tests for deployed serverless CRUD API"
    echo ""
    echo "Options:"
    echo "  --stage STAGE        Deployment stage (dev, staging, prod) [default: dev]"
    echo "  --region REGION      AWS region [default: us-east-1]"
    echo "  --timeout SECONDS    Test timeout in seconds [default: 60]"
    echo "  --verbose           Enable verbose output"
    echo "  --help              Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 --stage dev"
    echo "  $0 --stage prod --timeout 120 --verbose"
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

print_status $BLUE "💨 Starting smoke tests for $STAGE environment in $REGION"
print_status $BLUE "⏱️ Timeout: ${TIMEOUT}s"

# Set stack names
PROJECT_NAME="serverless-crud-api"
FOUNDATION_STACK="$PROJECT_NAME-$STAGE-foundation"
API_STACK="$PROJECT_NAME-$STAGE-api"

# Function to run test with timeout
run_test_with_timeout() {
    local test_name=$1
    local test_command=$2
    local timeout=$3
    
    print_status $YELLOW "🧪 Running: $test_name"
    
    if [ "$VERBOSE" = true ]; then
        print_status $BLUE "   Command: $test_command"
    fi
    
    if timeout "$timeout" bash -c "$test_command"; then
        print_status $GREEN "   ✅ $test_name passed"
        return 0
    else
        print_status $RED "   ❌ $test_name failed or timed out"
        return 1
    fi
}

# Start smoke tests
START_TIME=$(date +%s)
TESTS_FAILED=0

print_status $BLUE "🚀 Starting smoke test suite..."

# Test 1: Check CloudFormation stacks exist and are healthy
print_status $BLUE "\n📋 Test 1: CloudFormation Stack Health"

if run_test_with_timeout "Foundation Stack Check" \
   "aws cloudformation describe-stacks --stack-name '$FOUNDATION_STACK' --region '$REGION' --query 'Stacks[0].StackStatus' --output text | grep -E '(CREATE_COMPLETE|UPDATE_COMPLETE)'" \
   "$TIMEOUT"; then
    :
else
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi

if run_test_with_timeout "API Stack Check" \
   "aws cloudformation describe-stacks --stack-name '$API_STACK' --region '$REGION' --query 'Stacks[0].StackStatus' --output text | grep -E '(CREATE_COMPLETE|UPDATE_COMPLETE)'" \
   "$TIMEOUT"; then
    :
else
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi

# Test 2: Get API URL and validate it's accessible
print_status $BLUE "\n🌐 Test 2: API Gateway Accessibility"

API_URL=$(aws cloudformation describe-stacks \
    --stack-name "$API_STACK" \
    --region "$REGION" \
    --query 'Stacks[0].Outputs[?OutputKey==`ApiUrl`].OutputValue' \
    --output text 2>/dev/null || echo "")

if [[ -n "$API_URL" ]]; then
    print_status $GREEN "   ✅ API URL retrieved: $API_URL"
    
    # Test API is responding (expect 404 for non-existent endpoint, which means API is working)
    if run_test_with_timeout "API Connectivity" \
       "curl -s -f --max-time 30 '$API_URL/items/smoke-test' || curl -s --max-time 30 -w '%{http_code}' -o /dev/null '$API_URL/items/smoke-test' | grep -E '(404|400|401)'" \
       "$TIMEOUT"; then
        :
    else
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
else
    print_status $RED "   ❌ Failed to get API URL"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi

# Test 3: Check DynamoDB table
print_status $BLUE "\n🗄️ Test 3: DynamoDB Table Health"

TABLE_NAME=$(aws cloudformation describe-stacks \
    --stack-name "$FOUNDATION_STACK" \
    --region "$REGION" \
    --query 'Stacks[0].Outputs[?OutputKey==`ItemsTableName`].OutputValue' \
    --output text 2>/dev/null || echo "")

if [[ -n "$TABLE_NAME" ]]; then
    print_status $GREEN "   ✅ Table name retrieved: $TABLE_NAME"
    
    if run_test_with_timeout "DynamoDB Table Status" \
       "aws dynamodb describe-table --table-name '$TABLE_NAME' --region '$REGION' --query 'Table.TableStatus' --output text | grep 'ACTIVE'" \
       "$TIMEOUT"; then
        :
    else
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
else
    print_status $RED "   ❌ Failed to get table name"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi

# Test 4: Check Lambda functions
print_status $BLUE "\n⚡ Test 4: Lambda Functions Health"

LAMBDA_FUNCTIONS=(
    "$PROJECT_NAME-$STAGE-create-item"
    "$PROJECT_NAME-$STAGE-get-item"
    "$PROJECT_NAME-$STAGE-update-item"
    "$PROJECT_NAME-$STAGE-delete-item"
)

for func in "${LAMBDA_FUNCTIONS[@]}"; do
    if run_test_with_timeout "Lambda Function: $func" \
       "aws lambda get-function --function-name '$func' --region '$REGION' --query 'Configuration.State' --output text | grep 'Active'" \
       "$TIMEOUT"; then
        :
    else
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
done

# Test 5: Quick API functionality test (if API URL is available)
if [[ -n "$API_URL" ]]; then
    print_status $BLUE "\n🔄 Test 5: Basic API Functionality"
    
    # Test CORS preflight
    if run_test_with_timeout "CORS Preflight" \
       "curl -s --max-time 30 -X OPTIONS -H 'Origin: https://example.com' -H 'Access-Control-Request-Method: POST' '$API_URL/items' -w '%{http_code}' -o /dev/null | grep -E '(200|204)'" \
       "$TIMEOUT"; then
        :
    else
        print_status $YELLOW "   ⚠️ CORS preflight test failed (may be expected)"
    fi
    
    # Test GET request (should return 404 for non-existent item)
    if run_test_with_timeout "GET Request Test" \
       "curl -s --max-time 30 '$API_URL/items/smoke-test-id' -w '%{http_code}' -o /dev/null | grep '404'" \
       "$TIMEOUT"; then
        :
    else
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
    
    # Test POST request with invalid data (should return 400)
    if run_test_with_timeout "POST Validation Test" \
       "curl -s --max-time 30 -X POST -H 'Content-Type: application/json' -d '{\"invalid\":\"data\"}' '$API_URL/items' -w '%{http_code}' -o /dev/null | grep -E '(400|422)'" \
       "$TIMEOUT"; then
        :
    else
        print_status $YELLOW "   ⚠️ POST validation test failed (may be expected)"
    fi
fi

# Test 6: Check monitoring resources (optional)
print_status $BLUE "\n📊 Test 6: Monitoring Resources (Optional)"

MONITORING_STACK="$PROJECT_NAME-$STAGE-monitoring"

if aws cloudformation describe-stacks --stack-name "$MONITORING_STACK" --region "$REGION" >/dev/null 2>&1; then
    if run_test_with_timeout "Monitoring Stack Check" \
       "aws cloudformation describe-stacks --stack-name '$MONITORING_STACK' --region '$REGION' --query 'Stacks[0].StackStatus' --output text | grep -E '(CREATE_COMPLETE|UPDATE_COMPLETE)'" \
       "$TIMEOUT"; then
        :
    else
        print_status $YELLOW "   ⚠️ Monitoring stack check failed (non-critical)"
    fi
else
    print_status $BLUE "   ℹ️ Monitoring stack not found (may not be deployed)"
fi

# Calculate test duration
END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))

# Final results
print_status $BLUE "\n🏁 Smoke Test Results"
print_status $BLUE "⏱️ Total test time: ${DURATION}s"

if [ $TESTS_FAILED -eq 0 ]; then
    print_status $GREEN "✅ ALL SMOKE TESTS PASSED"
    print_status $GREEN "   Environment: $STAGE"
    print_status $GREEN "   Region: $REGION"
    if [[ -n "$API_URL" ]]; then
        print_status $GREEN "   API URL: $API_URL"
    fi
    print_status $GREEN "   The deployment appears to be healthy and ready for use"
else
    print_status $RED "❌ SMOKE TESTS FAILED"
    print_status $RED "   Failed tests: $TESTS_FAILED"
    print_status $YELLOW "   The deployment may have issues that need investigation"
    exit 1
fi

print_status $GREEN "💨 Smoke tests completed successfully!"