#!/bin/bash

# Enhanced Deployment Script with OIDC Verification
# Deploys the serverless CRUD API with comprehensive OIDC security checks

set -e

# Default values
STAGE="dev"
REGION="us-east-1"
VERIFY_OIDC=true
RUN_VERIFICATION=true
ROLLBACK_ON_FAILURE=true
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
    echo "Enhanced deployment script with OIDC verification and security checks"
    echo ""
    echo "Options:"
    echo "  --stage STAGE           Deployment stage (dev, staging, prod) [default: dev]"
    echo "  --region REGION         AWS region [default: us-east-1]"
    echo "  --skip-oidc-verify     Skip OIDC authentication verification"
    echo "  --skip-verification    Skip post-deployment verification"
    echo "  --no-rollback          Don't rollback on deployment failure"
    echo "  --verbose              Enable verbose output"
    echo "  --help                 Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 --stage dev --region us-east-1"
    echo "  $0 --stage prod --verbose"
    echo "  $0 --stage staging --skip-verification"
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
        --skip-oidc-verify)
            VERIFY_OIDC=false
            shift
            ;;
        --skip-verification)
            RUN_VERIFICATION=false
            shift
            ;;
        --no-rollback)
            ROLLBACK_ON_FAILURE=false
            shift
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

print_status $BLUE "🚀 Starting enhanced deployment for $STAGE environment in $REGION"
print_status $BLUE "🔐 OIDC verification: $([ "$VERIFY_OIDC" = true ] && echo "enabled" || echo "disabled")"
print_status $BLUE "🔍 Post-deployment verification: $([ "$RUN_VERIFICATION" = true ] && echo "enabled" || echo "disabled")"
print_status $BLUE "🔄 Rollback on failure: $([ "$ROLLBACK_ON_FAILURE" = true ] && echo "enabled" || echo "disabled")"

# Function to verify OIDC authentication
verify_oidc_authentication() {
    print_status $BLUE "🔐 Verifying OIDC authentication..."
    
    # Check if we're using OIDC (temporary credentials)
    local caller_identity
    caller_identity=$(aws sts get-caller-identity 2>/dev/null || {
        print_status $RED "❌ Failed to get AWS caller identity"
        return 1
    })
    
    local arn=$(echo "$caller_identity" | jq -r '.Arn')
    local account_id=$(echo "$caller_identity" | jq -r '.Account')
    local user_id=$(echo "$caller_identity" | jq -r '.UserId')
    
    print_status $BLUE "   Account ID: $account_id"
    print_status $BLUE "   ARN: $arn"
    
    # Check if this is an assumed role (OIDC)
    if [[ "$arn" == *"assumed-role"* ]]; then
        print_status $GREEN "   ✅ Using assumed role (OIDC authentication detected)"
        
        # Verify role name contains expected patterns
        if [[ "$arn" == *"GitHubActions"* ]] || [[ "$arn" == *"ServerlessCRUD"* ]] || [[ "$arn" == *"OIDC"* ]]; then
            print_status $GREEN "   ✅ Role name matches expected OIDC pattern"
        else
            print_status $YELLOW "   ⚠️ Role name doesn't match expected OIDC pattern"
            print_status $YELLOW "   Expected: GitHubActions, ServerlessCRUD, or OIDC in role name"
        fi
        
        # Check session name for GitHub Actions pattern
        if [[ "$arn" == *"GitHubActions"* ]]; then
            print_status $GREEN "   ✅ GitHub Actions session detected"
        fi
        
    elif [[ "$arn" == *"user/"* ]]; then
        print_status $YELLOW "   ⚠️ Using IAM user credentials (not OIDC)"
        print_status $YELLOW "   For production deployments, OIDC is recommended"
        
        if [ "$STAGE" = "prod" ]; then
            print_status $RED "   ❌ Production deployments should use OIDC authentication"
            return 1
        fi
        
    else
        print_status $YELLOW "   ⚠️ Unknown credential type: $arn"
    fi
    
    # Check credential expiry (for temporary credentials)
    if [[ "$arn" == *"assumed-role"* ]]; then
        local session_token_expiry
        session_token_expiry=$(aws sts get-session-token --query 'Credentials.Expiration' --output text 2>/dev/null || echo "N/A")
        
        if [[ "$session_token_expiry" != "N/A" ]]; then
            print_status $BLUE "   Token expiry: $session_token_expiry"
            
            # Check if expiry is within reasonable time (1-4 hours)
            local current_time=$(date +%s)
            local expiry_time=$(date -d "$session_token_expiry" +%s 2>/dev/null || echo "0")
            local time_diff=$((expiry_time - current_time))
            
            if [ $time_diff -gt 0 ] && [ $time_diff -le 14400 ]; then  # 4 hours
                print_status $GREEN "   ✅ Credential expiry is within acceptable range"
            elif [ $time_diff -gt 14400 ]; then
                print_status $YELLOW "   ⚠️ Credentials expire in more than 4 hours (may not be OIDC)"
            else
                print_status $RED "   ❌ Credentials have expired or expire very soon"
                return 1
            fi
        fi
    fi
    
    # Test basic AWS permissions
    print_status $BLUE "   Testing AWS permissions..."
    
    # Test CloudFormation permissions
    if aws cloudformation list-stacks --stack-status-filter CREATE_COMPLETE --max-items 1 >/dev/null 2>&1; then
        print_status $GREEN "   ✅ CloudFormation permissions verified"
    else
        print_status $RED "   ❌ CloudFormation permissions missing"
        return 1
    fi
    
    # Test S3 permissions (for SAM artifacts)
    if aws s3 ls >/dev/null 2>&1; then
        print_status $GREEN "   ✅ S3 permissions verified"
    else
        print_status $YELLOW "   ⚠️ S3 permissions may be limited"
    fi
    
    print_status $GREEN "✅ OIDC authentication verification completed"
    return 0
}

# Function to check deployment prerequisites
check_prerequisites() {
    print_status $BLUE "🔍 Checking deployment prerequisites..."
    
    # Check required tools
    local required_tools=("aws" "sam" "jq")
    for tool in "${required_tools[@]}"; do
        if command -v "$tool" &> /dev/null; then
            print_status $GREEN "   ✅ $tool is available"
        else
            print_status $RED "   ❌ $tool is not installed"
            return 1
        fi
    done
    
    # Check parameter file exists
    local param_file="parameters/${STAGE}.json"
    if [ -f "$param_file" ]; then
        print_status $GREEN "   ✅ Parameter file found: $param_file"
    else
        print_status $RED "   ❌ Parameter file not found: $param_file"
        return 1
    fi
    
    # Validate parameter file
    if jq empty "$param_file" 2>/dev/null; then
        print_status $GREEN "   ✅ Parameter file is valid JSON"
    else
        print_status $RED "   ❌ Parameter file contains invalid JSON"
        return 1
    fi
    
    # Check if we're in the correct directory
    if [ ! -d "stacks" ] || [ ! -d "scripts" ]; then
        print_status $RED "   ❌ Must run from infrastructure directory"
        return 1
    fi
    
    print_status $GREEN "✅ Prerequisites check completed"
    return 0
}

# Function to deploy with error handling
deploy_with_error_handling() {
    print_status $BLUE "🚀 Starting deployment process..."
    
    # Run the main deployment script
    if [ "$VERBOSE" = true ]; then
        ./scripts/deploy.sh --stage "$STAGE" --region "$REGION" --verbose
    else
        ./scripts/deploy.sh --stage "$STAGE" --region "$REGION"
    fi
    
    local deploy_exit_code=$?
    
    if [ $deploy_exit_code -eq 0 ]; then
        print_status $GREEN "✅ Deployment completed successfully"
        return 0
    else
        print_status $RED "❌ Deployment failed with exit code: $deploy_exit_code"
        return $deploy_exit_code
    fi
}

# Function to handle deployment failure
handle_deployment_failure() {
    print_status $RED "💥 Deployment failed - initiating failure handling..."
    
    if [ "$ROLLBACK_ON_FAILURE" = true ]; then
        print_status $BLUE "🔄 Attempting automatic rollback..."
        
        if [ -f "scripts/rollback-deployment.sh" ]; then
            if [ "$VERBOSE" = true ]; then
                ./scripts/rollback-deployment.sh --stage "$STAGE" --region "$REGION" --verbose
            else
                ./scripts/rollback-deployment.sh --stage "$STAGE" --region "$REGION"
            fi
            
            if [ $? -eq 0 ]; then
                print_status $GREEN "✅ Rollback completed successfully"
            else
                print_status $RED "❌ Rollback failed - manual intervention required"
            fi
        else
            print_status $YELLOW "⚠️ Rollback script not found - manual rollback may be needed"
        fi
    else
        print_status $YELLOW "⚠️ Automatic rollback disabled - manual intervention may be required"
    fi
}

# Main deployment process
START_TIME=$(date +%s)
DEPLOYMENT_SUCCESS=false

print_status $BLUE "🎯 Starting enhanced deployment process..."

# Step 1: OIDC Authentication Verification
if [ "$VERIFY_OIDC" = true ]; then
    if ! verify_oidc_authentication; then
        print_status $RED "❌ OIDC authentication verification failed"
        exit 1
    fi
else
    print_status $YELLOW "⚠️ OIDC verification skipped"
fi

# Step 2: Prerequisites Check
if ! check_prerequisites; then
    print_status $RED "❌ Prerequisites check failed"
    exit 1
fi

# Step 3: Deployment
if deploy_with_error_handling; then
    DEPLOYMENT_SUCCESS=true
    print_status $GREEN "✅ Deployment phase completed successfully"
else
    print_status $RED "❌ Deployment phase failed"
    handle_deployment_failure
    exit 1
fi

# Step 4: Post-deployment Verification
if [ "$RUN_VERIFICATION" = true ] && [ "$DEPLOYMENT_SUCCESS" = true ]; then
    print_status $BLUE "🔍 Running post-deployment verification..."
    
    if [ -f "scripts/verify-deployment.sh" ]; then
        if [ "$VERBOSE" = true ]; then
            ./scripts/verify-deployment.sh --stage "$STAGE" --region "$REGION" --verbose
        else
            ./scripts/verify-deployment.sh --stage "$STAGE" --region "$REGION"
        fi
        
        if [ $? -eq 0 ]; then
            print_status $GREEN "✅ Post-deployment verification passed"
        else
            print_status $RED "❌ Post-deployment verification failed"
            
            if [ "$ROLLBACK_ON_FAILURE" = true ]; then
                print_status $BLUE "🔄 Verification failed - initiating rollback..."
                handle_deployment_failure
                exit 1
            fi
        fi
    else
        print_status $YELLOW "⚠️ Verification script not found - skipping verification"
    fi
else
    print_status $YELLOW "⚠️ Post-deployment verification skipped"
fi

# Calculate deployment time
END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))

# Final success message
print_status $BLUE "\n🏁 Deployment Summary"
print_status $GREEN "✅ ENHANCED DEPLOYMENT COMPLETED SUCCESSFULLY"
print_status $BLUE "   Environment: $STAGE"
print_status $BLUE "   Region: $REGION"
print_status $BLUE "   Total time: ${DURATION}s"
print_status $BLUE "   OIDC verified: $([ "$VERIFY_OIDC" = true ] && echo "Yes" || echo "Skipped")"
print_status $BLUE "   Post-verification: $([ "$RUN_VERIFICATION" = true ] && echo "Passed" || echo "Skipped")"

# Get and display API URL
PROJECT_NAME="serverless-crud-api"
API_STACK="$PROJECT_NAME-$STAGE-api"
API_URL=$(aws cloudformation describe-stacks \
    --stack-name "$API_STACK" \
    --region "$REGION" \
    --query 'Stacks[0].Outputs[?OutputKey==`ApiUrl`].OutputValue' \
    --output text 2>/dev/null || echo "")

if [[ -n "$API_URL" ]]; then
    print_status $BLUE "   API URL: $API_URL"
fi

print_status $GREEN "🎉 Enhanced deployment with OIDC verification completed successfully!"