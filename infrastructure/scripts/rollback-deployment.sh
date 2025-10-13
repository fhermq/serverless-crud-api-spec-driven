#!/bin/bash

# Deployment Rollback Script
# Rolls back a failed deployment to the previous stable state

set -e

# Default values
STAGE="dev"
REGION="us-east-1"
DRY_RUN=false
FORCE=false
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
    echo "  --dry-run           Show what would be rolled back without executing"
    echo "  --force             Force rollback even if stack appears healthy"
    echo "  --verbose           Enable verbose output"
    echo "  --help              Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 --stage dev --region us-east-1"
    echo "  $0 --stage prod --dry-run"
    echo "  $0 --stage staging --force --verbose"
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
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --force)
            FORCE=true
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

print_status $BLUE "🔄 Starting deployment rollback for $STAGE environment in $REGION"

if [ "$DRY_RUN" = true ]; then
    print_status $YELLOW "🧪 DRY RUN MODE - No actual changes will be made"
fi

# Set stack names
PROJECT_NAME="serverless-crud-api"
FOUNDATION_STACK="$PROJECT_NAME-$STAGE-foundation"
API_STACK="$PROJECT_NAME-$STAGE-api"
MONITORING_STACK="$PROJECT_NAME-$STAGE-monitoring"

# Function to get stack status
get_stack_status() {
    local stack_name=$1
    
    aws cloudformation describe-stacks \
        --stack-name "$stack_name" \
        --region "$REGION" \
        --query 'Stacks[0].StackStatus' \
        --output text 2>/dev/null || echo "NOT_FOUND"
}

# Function to get stack events (last 10)
get_stack_events() {
    local stack_name=$1
    
    print_status $BLUE "📋 Recent events for $stack_name:"
    aws cloudformation describe-stack-events \
        --stack-name "$stack_name" \
        --region "$REGION" \
        --max-items 10 \
        --query 'StackEvents[*].[Timestamp,ResourceStatus,ResourceType,LogicalResourceId,ResourceStatusReason]' \
        --output table 2>/dev/null || echo "No events found"
}

# Function to check if rollback is needed
check_rollback_needed() {
    local stack_name=$1
    local status=$(get_stack_status "$stack_name")
    
    print_status $YELLOW "🔍 Checking if rollback is needed for $stack_name"
    print_status $BLUE "   Current status: $status"
    
    case $status in
        "UPDATE_FAILED"|"CREATE_FAILED"|"ROLLBACK_FAILED"|"UPDATE_ROLLBACK_FAILED")
            print_status $RED "   ❌ Stack is in failed state - rollback needed"
            return 0
            ;;
        "UPDATE_IN_PROGRESS"|"CREATE_IN_PROGRESS"|"ROLLBACK_IN_PROGRESS"|"UPDATE_ROLLBACK_IN_PROGRESS")
            print_status $YELLOW "   ⚠️ Stack operation in progress - may need intervention"
            return 0
            ;;
        "CREATE_COMPLETE"|"UPDATE_COMPLETE")
            if [ "$FORCE" = true ]; then
                print_status $YELLOW "   ⚠️ Stack appears healthy but force rollback requested"
                return 0
            else
                print_status $GREEN "   ✅ Stack is healthy - no rollback needed"
                return 1
            fi
            ;;
        "NOT_FOUND")
            print_status $BLUE "   ℹ️ Stack not found - no rollback needed"
            return 1
            ;;
        *)
            print_status $YELLOW "   ⚠️ Unknown stack status: $status"
            return 0
            ;;
    esac
}

# Function to perform stack rollback
rollback_stack() {
    local stack_name=$1
    local status=$(get_stack_status "$stack_name")
    
    print_status $BLUE "🔄 Rolling back stack: $stack_name"
    
    if [ "$DRY_RUN" = true ]; then
        print_status $YELLOW "   [DRY RUN] Would rollback stack with status: $status"
        return 0
    fi
    
    case $status in
        "UPDATE_FAILED")
            print_status $YELLOW "   Canceling failed update and rolling back..."
            aws cloudformation cancel-update-stack \
                --stack-name "$stack_name" \
                --region "$REGION" 2>/dev/null || true
            
            sleep 10
            
            aws cloudformation continue-update-rollback \
                --stack-name "$stack_name" \
                --region "$REGION"
            ;;
        "CREATE_FAILED")
            print_status $YELLOW "   Deleting failed stack creation..."
            aws cloudformation delete-stack \
                --stack-name "$stack_name" \
                --region "$REGION"
            ;;
        "ROLLBACK_FAILED"|"UPDATE_ROLLBACK_FAILED")
            print_status $YELLOW "   Continuing failed rollback..."
            aws cloudformation continue-update-rollback \
                --stack-name "$stack_name" \
                --region "$REGION"
            ;;
        "UPDATE_IN_PROGRESS")
            print_status $YELLOW "   Canceling in-progress update..."
            aws cloudformation cancel-update-stack \
                --stack-name "$stack_name" \
                --region "$REGION"
            ;;
        "CREATE_COMPLETE"|"UPDATE_COMPLETE")
            if [ "$FORCE" = true ]; then
                print_status $YELLOW "   Force rollback requested - initiating rollback to previous version..."
                # This would require tracking previous template versions
                print_status $YELLOW "   ⚠️ Manual rollback to previous template version not implemented"
                print_status $YELLOW "   Consider using CloudFormation change sets for safer rollbacks"
            fi
            ;;
        *)
            print_status $RED "   ❌ Cannot rollback stack in status: $status"
            return 1
            ;;
    esac
    
    return 0
}

# Function to wait for rollback completion
wait_for_rollback() {
    local stack_name=$1
    local timeout=1800  # 30 minutes
    local start_time=$(date +%s)
    
    print_status $BLUE "⏳ Waiting for rollback to complete for $stack_name..."
    
    if [ "$DRY_RUN" = true ]; then
        print_status $YELLOW "   [DRY RUN] Would wait for rollback completion"
        return 0
    fi
    
    while true; do
        local current_time=$(date +%s)
        local elapsed=$((current_time - start_time))
        
        if [ $elapsed -gt $timeout ]; then
            print_status $RED "   ❌ Rollback timeout after ${timeout}s"
            return 1
        fi
        
        local status=$(get_stack_status "$stack_name")
        
        case $status in
            "UPDATE_ROLLBACK_COMPLETE"|"DELETE_COMPLETE")
                print_status $GREEN "   ✅ Rollback completed successfully"
                return 0
                ;;
            "UPDATE_ROLLBACK_FAILED"|"DELETE_FAILED")
                print_status $RED "   ❌ Rollback failed"
                get_stack_events "$stack_name"
                return 1
                ;;
            "UPDATE_ROLLBACK_IN_PROGRESS"|"DELETE_IN_PROGRESS")
                if [ "$VERBOSE" = true ]; then
                    print_status $BLUE "   Rolling back... (${elapsed}s elapsed)"
                fi
                sleep 30
                ;;
            "NOT_FOUND")
                print_status $GREEN "   ✅ Stack deleted successfully"
                return 0
                ;;
            *)
                if [ "$VERBOSE" = true ]; then
                    print_status $BLUE "   Status: $status (${elapsed}s elapsed)"
                fi
                sleep 30
                ;;
        esac
    done
}

# Function to backup current state before rollback
backup_current_state() {
    local stack_name=$1
    
    print_status $BLUE "💾 Backing up current state for $stack_name"
    
    if [ "$DRY_RUN" = true ]; then
        print_status $YELLOW "   [DRY RUN] Would backup current stack template and parameters"
        return 0
    fi
    
    local backup_dir="rollback-backups/$(date +%Y%m%d-%H%M%S)"
    mkdir -p "$backup_dir"
    
    # Backup current template
    aws cloudformation get-template \
        --stack-name "$stack_name" \
        --region "$REGION" \
        --query 'TemplateBody' \
        > "$backup_dir/${stack_name}-template.json" 2>/dev/null || true
    
    # Backup current parameters
    aws cloudformation describe-stacks \
        --stack-name "$stack_name" \
        --region "$REGION" \
        --query 'Stacks[0].Parameters' \
        > "$backup_dir/${stack_name}-parameters.json" 2>/dev/null || true
    
    print_status $GREEN "   ✅ Backup saved to $backup_dir"
}

# Main rollback process
print_status $BLUE "🚀 Starting rollback analysis..."

# Check if any stacks need rollback
STACKS_TO_ROLLBACK=()

# Check stacks in reverse order (API -> Foundation)
for stack in "$API_STACK" "$FOUNDATION_STACK"; do
    if check_rollback_needed "$stack"; then
        STACKS_TO_ROLLBACK+=("$stack")
    fi
done

# Also check monitoring stack (optional)
if check_rollback_needed "$MONITORING_STACK"; then
    STACKS_TO_ROLLBACK=("$MONITORING_STACK" "${STACKS_TO_ROLLBACK[@]}")
fi

if [ ${#STACKS_TO_ROLLBACK[@]} -eq 0 ]; then
    print_status $GREEN "✅ No stacks require rollback"
    exit 0
fi

print_status $YELLOW "⚠️ Stacks requiring rollback: ${STACKS_TO_ROLLBACK[*]}"

# Confirm rollback (unless dry run or force)
if [ "$DRY_RUN" = false ] && [ "$FORCE" = false ]; then
    print_status $YELLOW "⚠️ This will rollback the following stacks:"
    for stack in "${STACKS_TO_ROLLBACK[@]}"; do
        print_status $YELLOW "   - $stack"
    done
    
    read -p "Are you sure you want to proceed? (yes/no): " -r
    if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
        print_status $BLUE "Rollback cancelled by user"
        exit 0
    fi
fi

# Perform rollback for each stack
ROLLBACK_SUCCESS=true

for stack in "${STACKS_TO_ROLLBACK[@]}"; do
    print_status $BLUE "\n🔄 Processing rollback for $stack"
    
    # Backup current state
    backup_current_state "$stack"
    
    # Show recent events
    if [ "$VERBOSE" = true ]; then
        get_stack_events "$stack"
    fi
    
    # Perform rollback
    if rollback_stack "$stack"; then
        if wait_for_rollback "$stack"; then
            print_status $GREEN "✅ Successfully rolled back $stack"
        else
            print_status $RED "❌ Failed to complete rollback for $stack"
            ROLLBACK_SUCCESS=false
        fi
    else
        print_status $RED "❌ Failed to initiate rollback for $stack"
        ROLLBACK_SUCCESS=false
    fi
done

# Final status
print_status $BLUE "\n🏁 Rollback Summary"

if [ "$ROLLBACK_SUCCESS" = true ]; then
    print_status $GREEN "✅ ROLLBACK COMPLETED SUCCESSFULLY"
    print_status $GREEN "   All failed stacks have been rolled back"
    
    # Run verification after rollback
    if [ "$DRY_RUN" = false ]; then
        print_status $BLUE "🔍 Running post-rollback verification..."
        if command -v ./verify-deployment.sh &> /dev/null; then
            ./verify-deployment.sh --stage "$STAGE" --region "$REGION" || true
        fi
    fi
else
    print_status $RED "❌ ROLLBACK FAILED"
    print_status $RED "   Some stacks could not be rolled back"
    print_status $YELLOW "   Manual intervention may be required"
    exit 1
fi

print_status $GREEN "🎉 Rollback process completed!"