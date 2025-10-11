#!/bin/bash

# Validate OIDC Identity Provider and Deployment Role Configuration
# This script helps verify that OIDC is properly configured

set -e

# Default values
STAGE="dev"
REGION="us-east-1"
PROJECT_NAME="serverless-crud-api"

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
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --stage STAGE               Deployment stage (default: dev)"
    echo "  --region REGION             AWS region (default: us-east-1)"
    echo "  --project-name NAME         Project name (default: serverless-crud-api)"
    echo "  --help                      Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0"
    echo "  $0 --stage prod --region us-west-2"
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
        --project-name)
            PROJECT_NAME="$2"
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

print_status "Validating OIDC configuration for stage: $STAGE, region: $REGION"

# Check if foundation stack exists
STACK_NAME="${PROJECT_NAME}-${STAGE}-foundation"
print_status "Checking foundation stack: $STACK_NAME"

if ! aws cloudformation describe-stacks --stack-name "$STACK_NAME" --region "$REGION" &>/dev/null; then
    print_error "Foundation stack '$STACK_NAME' does not exist"
    print_error "Please run './scripts/setup-oidc.sh --github-repo YOUR_ORG/YOUR_REPO' first"
    exit 1
fi

print_success "Foundation stack exists"

# Get stack outputs
print_status "Retrieving stack outputs..."
STACK_OUTPUTS=$(aws cloudformation describe-stacks \
    --stack-name "$STACK_NAME" \
    --region "$REGION" \
    --query 'Stacks[0].Outputs')

# Check for OIDC Provider
OIDC_PROVIDER_ARN=$(echo "$STACK_OUTPUTS" | jq -r '.[] | select(.OutputKey=="GitHubOIDCProviderArn") | .OutputValue // empty')
if [[ -n "$OIDC_PROVIDER_ARN" && "$OIDC_PROVIDER_ARN" != "null" ]]; then
    print_success "OIDC Identity Provider found: $OIDC_PROVIDER_ARN"
    
    # Validate OIDC provider configuration
    print_status "Validating OIDC provider configuration..."
    PROVIDER_INFO=$(aws iam get-open-id-connect-provider --open-id-connect-provider-arn "$OIDC_PROVIDER_ARN" 2>/dev/null || echo "")
    
    if [[ -n "$PROVIDER_INFO" ]]; then
        PROVIDER_URL=$(echo "$PROVIDER_INFO" | jq -r '.Url')
        CLIENT_IDS=$(echo "$PROVIDER_INFO" | jq -r '.ClientIDList[]')
        THUMBPRINTS=$(echo "$PROVIDER_INFO" | jq -r '.ThumbprintList[]')
        
        if [[ "$PROVIDER_URL" == "https://token.actions.githubusercontent.com" ]]; then
            print_success "OIDC provider URL is correct"
        else
            print_error "OIDC provider URL is incorrect: $PROVIDER_URL"
        fi
        
        if echo "$CLIENT_IDS" | grep -q "sts.amazonaws.com"; then
            print_success "OIDC client ID includes sts.amazonaws.com"
        else
            print_error "OIDC client ID does not include sts.amazonaws.com"
        fi
        
        print_status "OIDC thumbprints: $THUMBPRINTS"
    else
        print_error "Could not retrieve OIDC provider information"
    fi
else
    print_warning "OIDC Identity Provider not found in stack outputs"
    print_warning "This may indicate the stack was deployed without GitHub repository parameter"
fi

# Check for Deployment Role
DEPLOYMENT_ROLE_ARN=$(echo "$STACK_OUTPUTS" | jq -r '.[] | select(.OutputKey=="GitHubActionsDeploymentRoleArn") | .OutputValue // empty')
if [[ -n "$DEPLOYMENT_ROLE_ARN" && "$DEPLOYMENT_ROLE_ARN" != "null" ]]; then
    print_success "GitHub Actions deployment role found: $DEPLOYMENT_ROLE_ARN"
    
    # Validate deployment role configuration
    print_status "Validating deployment role configuration..."
    ROLE_NAME=$(echo "$DEPLOYMENT_ROLE_ARN" | awk -F'/' '{print $NF}')
    ROLE_INFO=$(aws iam get-role --role-name "$ROLE_NAME" 2>/dev/null || echo "")
    
    if [[ -n "$ROLE_INFO" ]]; then
        MAX_SESSION_DURATION=$(echo "$ROLE_INFO" | jq -r '.Role.MaxSessionDuration')
        if [[ "$MAX_SESSION_DURATION" == "3600" ]]; then
            print_success "Role max session duration is correctly set to 1 hour"
        else
            print_warning "Role max session duration is $MAX_SESSION_DURATION seconds (expected: 3600)"
        fi
        
        # Check trust policy
        TRUST_POLICY=$(echo "$ROLE_INFO" | jq -r '.Role.AssumeRolePolicyDocument')
        if echo "$TRUST_POLICY" | jq -e '.Statement[] | select(.Principal.Federated | contains("oidc-provider/token.actions.githubusercontent.com"))' &>/dev/null; then
            print_success "Role trust policy includes GitHub OIDC provider"
        else
            print_error "Role trust policy does not include GitHub OIDC provider"
        fi
        
        # Check for repository restriction in trust policy
        if echo "$TRUST_POLICY" | jq -e '.Statement[].Condition.StringEquals."token.actions.githubusercontent.com:sub"' &>/dev/null; then
            REPO_RESTRICTION=$(echo "$TRUST_POLICY" | jq -r '.Statement[].Condition.StringEquals."token.actions.githubusercontent.com:sub"')
            print_success "Role is restricted to repository: $REPO_RESTRICTION"
        else
            print_warning "Role trust policy does not include repository restriction"
        fi
    else
        print_error "Could not retrieve deployment role information"
    fi
    
    # Check attached policies
    print_status "Checking attached policies..."
    ATTACHED_POLICIES=$(aws iam list-attached-role-policies --role-name "$ROLE_NAME" --query 'AttachedPolicies[].PolicyName' --output text 2>/dev/null || echo "")
    INLINE_POLICIES=$(aws iam list-role-policies --role-name "$ROLE_NAME" --query 'PolicyNames' --output text 2>/dev/null || echo "")
    
    if [[ -n "$ATTACHED_POLICIES" ]]; then
        print_status "Attached managed policies: $ATTACHED_POLICIES"
    fi
    
    if [[ -n "$INLINE_POLICIES" ]]; then
        print_status "Inline policies: $INLINE_POLICIES"
        
        # Check deployment policy permissions
        for policy in $INLINE_POLICIES; do
            if [[ "$policy" == *"deploy"* ]]; then
                print_status "Checking deployment policy permissions..."
                POLICY_DOC=$(aws iam get-role-policy --role-name "$ROLE_NAME" --policy-name "$policy" --query 'PolicyDocument' 2>/dev/null || echo "")
                
                # Check for key permissions
                if echo "$POLICY_DOC" | jq -e '.Statement[] | select(.Action[] | contains("cloudformation:"))' &>/dev/null; then
                    print_success "Policy includes CloudFormation permissions"
                fi
                
                if echo "$POLICY_DOC" | jq -e '.Statement[] | select(.Action[] | contains("lambda:"))' &>/dev/null; then
                    print_success "Policy includes Lambda permissions"
                fi
                
                if echo "$POLICY_DOC" | jq -e '.Statement[] | select(.Action[] | contains("apigateway:"))' &>/dev/null; then
                    print_success "Policy includes API Gateway permissions"
                fi
                
                if echo "$POLICY_DOC" | jq -e '.Statement[] | select(.Action[] | contains("iam:"))' &>/dev/null; then
                    print_success "Policy includes IAM permissions"
                fi
            fi
        done
    fi
else
    print_warning "GitHub Actions deployment role not found in stack outputs"
    print_warning "This may indicate the stack was deployed without GitHub repository parameter"
fi

# Check other required outputs
print_status "Checking other stack outputs..."

ITEMS_TABLE_NAME=$(echo "$STACK_OUTPUTS" | jq -r '.[] | select(.OutputKey=="ItemsTableName") | .OutputValue')
if [[ -n "$ITEMS_TABLE_NAME" && "$ITEMS_TABLE_NAME" != "null" ]]; then
    print_success "DynamoDB table: $ITEMS_TABLE_NAME"
else
    print_error "DynamoDB table name not found in outputs"
fi

BASE_LAMBDA_ROLE_ARN=$(echo "$STACK_OUTPUTS" | jq -r '.[] | select(.OutputKey=="BaseLambdaExecutionRoleArn") | .OutputValue')
if [[ -n "$BASE_LAMBDA_ROLE_ARN" && "$BASE_LAMBDA_ROLE_ARN" != "null" ]]; then
    print_success "Base Lambda execution role: $BASE_LAMBDA_ROLE_ARN"
else
    print_error "Base Lambda execution role ARN not found in outputs"
fi

# Summary
echo ""
print_status "=== OIDC Validation Summary ==="

if [[ -n "$OIDC_PROVIDER_ARN" && -n "$DEPLOYMENT_ROLE_ARN" ]]; then
    print_success "OIDC is properly configured!"
    echo ""
    print_status "Next steps:"
    echo "1. Add this secret to your GitHub repository:"
    echo "   Name: AWS_DEPLOYMENT_ROLE_ARN"
    echo "   Value: $DEPLOYMENT_ROLE_ARN"
    echo ""
    echo "2. Update your GitHub Actions workflow to use OIDC:"
    echo "   permissions:"
    echo "     id-token: write"
    echo "     contents: read"
    echo ""
    echo "   - name: Configure AWS credentials via OIDC"
    echo "     uses: aws-actions/configure-aws-credentials@v4"
    echo "     with:"
    echo "       role-to-assume: \${{ secrets.AWS_DEPLOYMENT_ROLE_ARN }}"
    echo "       role-session-name: GitHubActions-ServerlessCRUD"
    echo "       aws-region: $REGION"
else
    print_warning "OIDC is not fully configured"
    print_status "To set up OIDC, run:"
    echo "  ./scripts/setup-oidc.sh --github-repo YOUR_ORG/YOUR_REPO --stage $STAGE --region $REGION"
fi