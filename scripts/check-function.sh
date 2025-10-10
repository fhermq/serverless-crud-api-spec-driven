#!/bin/bash

# Lambda Function Quality Check Script
# Run this script to validate a Lambda function before committing

set -e

FUNCTION_DIR="$1"

if [ -z "$FUNCTION_DIR" ]; then
    echo "Usage: $0 <function-directory>"
    echo "Example: $0 functions/get-item"
    exit 1
fi

if [ ! -d "$FUNCTION_DIR" ]; then
    echo "❌ Directory $FUNCTION_DIR does not exist"
    exit 1
fi

echo "🔍 Checking Lambda function: $FUNCTION_DIR"
echo "================================================"

# Change to function directory
cd "$FUNCTION_DIR"

# Determine function type
if [ -f "package.json" ]; then
    FUNCTION_TYPE="nodejs"
elif [ -f "go.mod" ]; then
    FUNCTION_TYPE="go"
else
    echo "❌ Cannot determine function type (missing package.json or go.mod)"
    exit 1
fi

echo "📋 Function type: $FUNCTION_TYPE"

# Check required files
echo ""
echo "📁 Checking file structure..."

if [ "$FUNCTION_TYPE" = "nodejs" ]; then
    required_files=("package.json" "index.js" "README.md")
    for file in "${required_files[@]}"; do
        if [ -f "$file" ]; then
            echo "✅ $file"
        else
            echo "❌ Missing: $file"
            exit 1
        fi
    done
    
    # Check for test files
    if ls *.test.js 1> /dev/null 2>&1; then
        echo "✅ Test files found"
    else
        echo "❌ No test files found (*.test.js)"
        exit 1
    fi
    
elif [ "$FUNCTION_TYPE" = "go" ]; then
    required_files=("go.mod" "main.go" "README.md")
    for file in "${required_files[@]}"; do
        if [ -f "$file" ]; then
            echo "✅ $file"
        else
            echo "❌ Missing: $file"
            exit 1
        fi
    done
    
    # Check for test files
    if ls *_test.go 1> /dev/null 2>&1; then
        echo "✅ Test files found"
    else
        echo "❌ No test files found (*_test.go)"
        exit 1
    fi
fi

# Install dependencies and run checks
echo ""
echo "📦 Installing dependencies..."

if [ "$FUNCTION_TYPE" = "nodejs" ]; then
    npm install
    
    echo ""
    echo "🔍 Running linting..."
    npm run lint
    
    echo ""
    echo "🧪 Running tests..."
    npm test
    
    echo ""
    echo "📊 Checking test coverage..."
    npm run test:coverage
    
    echo ""
    echo "🔒 Running security audit..."
    npm audit --audit-level=moderate
    
elif [ "$FUNCTION_TYPE" = "go" ]; then
    go mod download
    
    echo ""
    echo "🔍 Running go fmt..."
    if [ "$(gofmt -s -l . | wc -l)" -gt 0 ]; then
        echo "❌ Code is not properly formatted:"
        gofmt -s -l .
        exit 1
    else
        echo "✅ Code is properly formatted"
    fi
    
    echo ""
    echo "🔍 Running go vet..."
    go vet ./...
    
    echo ""
    echo "🧪 Running tests..."
    go test -v -race -coverprofile=coverage.out ./...
    
    echo ""
    echo "📊 Checking test coverage..."
    go tool cover -func=coverage.out
fi

# Check for hardcoded values
echo ""
echo "🔍 Checking for hardcoded values..."
if grep -r "localhost\|127.0.0.1\|hardcoded" . --exclude-dir=node_modules --exclude="*.test.*" --exclude="coverage.out" --exclude="main" --exclude="*.md" --exclude-dir=.git; then
    echo "❌ Hardcoded values found"
    exit 1
else
    echo "✅ No hardcoded values found"
fi

# Check README content
echo ""
echo "📖 Checking README content..."
required_sections=("## Overview" "## Responsibilities" "## Environment Variables")
for section in "${required_sections[@]}"; do
    if grep -q "$section" README.md; then
        echo "✅ $section"
    else
        echo "❌ Missing README section: $section"
        exit 1
    fi
done

# Check shared utilities usage (Node.js only)
if [ "$FUNCTION_TYPE" = "nodejs" ]; then
    echo ""
    echo "🔗 Checking shared utilities usage..."
    if grep -q "@serverless-crud-api/shared" package.json; then
        echo "✅ Uses shared utilities"
    else
        echo "❌ Should use shared utilities (@serverless-crud-api/shared)"
        exit 1
    fi
fi

echo ""
echo "🎉 All checks passed! Function is ready for commit."
echo ""
echo "Next steps:"
echo "1. Create a pull request"
echo "2. Ensure all CI/CD checks pass"
echo "3. Request code review"
echo "4. Deploy after approval"