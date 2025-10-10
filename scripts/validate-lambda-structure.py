#!/usr/bin/env python3
"""
Lambda Function Structure Validator

This script validates that Lambda functions follow the required structure
and best practices defined in the project.
"""

import os
import json
import sys
from pathlib import Path

def validate_nodejs_function(function_dir):
    """Validate Node.js Lambda function structure."""
    errors = []
    
    # Check required files
    required_files = ['package.json', 'index.js', 'README.md']
    for file in required_files:
        if not (function_dir / file).exists():
            errors.append(f"Missing required file: {file}")
    
    # Check package.json structure
    package_json_path = function_dir / 'package.json'
    if package_json_path.exists():
        try:
            with open(package_json_path) as f:
                package_data = json.load(f)
            
            # Check required scripts
            scripts = package_data.get('scripts', {})
            required_scripts = ['test', 'lint']
            for script in required_scripts:
                if script not in scripts:
                    errors.append(f"Missing required script in package.json: {script}")
            
            # Check for shared dependency
            dependencies = package_data.get('dependencies', {})
            if '@serverless-crud-api/shared' not in dependencies:
                errors.append("Missing shared utilities dependency")
            
            # Check AWS SDK version
            if '@aws-sdk/client-dynamodb' not in dependencies:
                errors.append("Missing AWS SDK v3 DynamoDB client")
                
        except json.JSONDecodeError:
            errors.append("Invalid package.json format")
    
    # Check test file exists
    test_files = list(function_dir.glob('*.test.js'))
    if not test_files:
        errors.append("No test files found (*.test.js)")
    
    return errors

def validate_go_function(function_dir):
    """Validate Go Lambda function structure."""
    errors = []
    
    # Check required files
    required_files = ['go.mod', 'main.go', 'README.md']
    for file in required_files:
        if not (function_dir / file).exists():
            errors.append(f"Missing required file: {file}")
    
    # Check for test files
    test_files = list(function_dir.glob('*_test.go'))
    if not test_files:
        errors.append("No test files found (*_test.go)")
    
    return errors

def validate_function_directory(function_dir):
    """Validate a single Lambda function directory."""
    function_name = function_dir.name
    errors = []
    
    # Check if it's a Node.js or Go function
    if (function_dir / 'package.json').exists():
        errors.extend(validate_nodejs_function(function_dir))
    elif (function_dir / 'go.mod').exists():
        errors.extend(validate_go_function(function_dir))
    else:
        errors.append("Cannot determine function type (missing package.json or go.mod)")
    
    # Check README content
    readme_path = function_dir / 'README.md'
    if readme_path.exists():
        with open(readme_path) as f:
            readme_content = f.read()
        
        required_sections = ['## Overview', '## Responsibilities', '## Environment Variables']
        for section in required_sections:
            if section not in readme_content:
                errors.append(f"Missing required README section: {section}")
    
    return function_name, errors

def main():
    """Main validation function."""
    functions_dir = Path('functions')
    
    if not functions_dir.exists():
        print("No functions directory found")
        return 0
    
    total_errors = 0
    
    for function_dir in functions_dir.iterdir():
        if function_dir.is_dir() and not function_dir.name.startswith('.'):
            function_name, errors = validate_function_directory(function_dir)
            
            if errors:
                print(f"\n❌ {function_name}:")
                for error in errors:
                    print(f"  - {error}")
                total_errors += len(errors)
            else:
                print(f"✅ {function_name}: All checks passed")
    
    if total_errors > 0:
        print(f"\n❌ Validation failed with {total_errors} errors")
        return 1
    else:
        print(f"\n✅ All Lambda functions passed validation")
        return 0

if __name__ == '__main__':
    sys.exit(main())