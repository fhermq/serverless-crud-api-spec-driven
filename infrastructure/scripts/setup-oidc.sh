#!/bin/bash

# Setup OIDC Identity Provider and Deployment Role for GitHub Actions
# This script helps configure OIDC authentication for secure deployments

set -e

# Default values
STAGE="dev"
REGION="us-east-1"
PROJECT_NAME="serverless-crud-api"
GITHUB_REPO=""
GITHUB_BRANCH="main"

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
    echo "Usage: $0 --github-repo OWNER/REPO [OPTIONS]"
    echo ""
    echo "Required:"
    echo "  --github-repo OWNER/REPO    GitHub repository in format 'owner/repo'"
    echo ""
    echo "Options:"
    echo "  --stage STAGE               Deployment stage (default: dev)"
    echo "  --region REGION             AWS region (default: us-east-1)"
    echo "  --project-name NAME         Project name (default: serverless-crud-api)"
    echo "  --github-branch BRANCH      GitHub branch (default: main)"
    echo "  --help                      Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 --github-repo myorg/my-serverless-api"
    echo "  $0 --github-repo myorg/my-serverless-api --stage prod --region us-west-2"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --github-repo)
            GITHUB_REPO="$2"
            shift 2
            ;;
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
        --github-branch)
            GITHUB_BRANCH="$2"
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

# Validate required parameters
if [[ -z "$GITHUB_REPO" ]]; then
    print_error "GitHub repository is required"
    show_usage
    exit 1
fi

# Validate GitHub repo format
if [[ ! "$GITHUB_REPO" =~ ^[a-zA-Z0-9_.-]+/[a-zA-Z0-9_.-]+$ ]]; then
    print_error "Invalid GitHub repository format. Expected: owner/repo"
    exit 1
fi

# Check if AWS CLI is configured
if ! aws sts get-caller-identity &>/dev/null; then
    print_error "AWS CLI is not configured or credentials are invalid"
    print_error "Please run 'aws configure' or set up your AWS credentials"
    exit 1
fi

print_status "Setting up OIDC for GitHub Actions deployment..."
print_status "Repository: $GITHUB_REPO"
print_status "Stage: $STAGE"
print_status "Region: $REGION"
print_status "Branch: $GITHUB_BRANCH"

# Get the directory of this script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INFRASTRUCTURE_DIR="$(dirname "$SCRIPT_DIR")"

# Check if foundation stack exists
STACK_NAME="${PROJECT_NAME}-${STAGE}-foundation"
print_status "Checking if foundation stack exists: $STACK_NAME"

if aws cloudformation describe-stacks --stack-name "$STACK_NAME" --region "$REGION" &>/dev/null; then
    print_status "Foundation stack exists. Updating with OIDC configuration..."
    
    # Update the existing stack with OIDC parameters
    aws cloudformation update-stack \
        --stack-name "$STACK_NAME" \
        --template-body "file://${INFRASTRUCTURE_DIR}/stacks/01-foundation.yaml" \
        --parameters \
            ParameterKey=Stage,ParameterValue="$STAGE" \
            ParameterKey=ProjectName,ParameterValue="$PROJECT_NAME" \
            ParameterKey=GitHubRepository,ParameterValue="$GITHUB_REPO" \
            ParameterKey=GitHubBranch,ParameterValue="$GITHUB_BRANCH" \
        --capabilities CAPABILITY_NAMED_IAM \
        --region "$REGION"
    
    print_status "Waiting for stack update to complete..."
    aws cloudformation wait stack-update-complete \
        --stack-name "$STACK_NAME" \
        --region "$REGION"
    
    print_success "Foundation stack updated successfully with OIDC configuration"
else
    print_status "Foundation stack does not exist. Creating with OIDC configuration..."
    
    # Create the stack with OIDC parameters
    aws cloudformation create-stack \
        --stack-name "$STACK_NAME" \
        --template-body "file://${INFRASTRUCTURE_DIR}/stacks/01-foundation.yaml" \
        --parameters \
            ParameterKey=Stage,ParameterValue="$STAGE" \
            ParameterKey=ProjectName,ParameterValue="$PROJECT_NAME" \
            ParameterKey=GitHubRepository,ParameterValue="$GITHUB_REPO" \
            ParameterKey=GitHubBranch,ParameterValue="$GITHUB_BRANCH" \
        --capabilities CAPABILITY_NAMED_IAM \
        --region "$REGION"
    
    print_status "Waiting for stack creation to complete..."
    aws cloudformation wait stack-create-complete \
        --stack-name "$STACK_NAME" \
        --region "$REGION"
    
    print_success "Foundation stack created successfully with OIDC configuration"
fi

# Get the deployment role ARN
print_status "Retrieving OIDC deployment role ARN..."
DEPLOYMENT_ROLE_ARN=$(aws cloudformation describe-stacks \
    --stack-name "$STACK_NAME" \
    --region "$REGION" \
    --query 'Stacks[0].Outputs[?OutputKey==`GitHubActionsDeploymentRoleArn`].OutputValue' \
    --output text)

if [[ -z "$DEPLOYMENT_ROLE_ARN" || "$DEPLOYMENT_ROLE_ARN" == "None" ]]; then
    print_error "Could not retrieve deployment role ARN. OIDC setup may have failed."
    exit 1
fi

print_success "OIDC setup completed successfully!"
echo ""
print_status "Next steps:"
echo "1. Add the following GitHub repository secret:"
echo "   Secret name: AWS_DEPLOYMENT_ROLE_ARN"
echo "   Secret value: $DEPLOYMENT_ROLE_ARN"
echo ""
echo "2. Update your GitHub Actions workflow to use OIDC authentication:"
echo "   Replace the 'Configure AWS credentials' step with:"
echo ""
echo "   - name: Configure AWS credentials via OIDC"
echo "     uses: aws-actions/configure-aws-credentials@v4"
echo "     with:"
echo "       role-to-assume: \${{ secrets.AWS_DEPLOYMENT_ROLE_ARN }}"
echo "       role-session-name: GitHubActions-ServerlessCRUD"
echo "       aws-region: $REGION"
echo ""
echo "3. Remove the old AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY secrets"
echo "4. Ensure your workflow has the required OIDC permissions:"
echo "   permissions:"
echo "     id-token: write"
echo "     contents: read"
echo ""
print_warning "Important: The deployment role is restricted to the repository '$GITHUB_REPO' and branch '$GITHUB_BRANCH'"
print_warning "If you need to deploy from different branches, update the trust policy accordingly"