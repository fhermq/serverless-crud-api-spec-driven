#!/usr/bin/env python3
"""
Package.json Validator for Lambda Functions

This script validates that package.json files in Lambda functions
follow the required structure and best practices.
"""

import json
import sys
from pathlib import Path

def validate_package_json(package_path):
    """Validate a single package.json file."""
    errors = []
    
    try:
        with open(package_path) as f:
            package_data = json.load(f)
    except json.JSONDecodeError as e:
        return [f"Invalid JSON format: {e}"]
    
    # Required fields
    required_fields = ['name', 'version', 'description', 'main']
    for field in required_fields:
        if field not in package_data:
            errors.append(f"Missing required field: {field}")
    
    # Required scripts
    scripts = package_data.get('scripts', {})
    required_scripts = {
        'test': 'jest',
        'lint': 'eslint'
    }
    
    for script_name, expected_tool in required_scripts.items():
        if script_name not in scripts:
            errors.append(f"Missing required script: {script_name}")
        elif expected_tool not in scripts[script_name]:
            errors.append(f"Script '{script_name}' should use {expected_tool}")
    
    # Required dependencies
    dependencies = package_data.get('dependencies', {})
    required_deps = [
        '@aws-sdk/client-dynamodb',
        '@aws-sdk/lib-dynamodb',
        '@serverless-crud-api/shared'
    ]
    
    for dep in required_deps:
        if dep not in dependencies:
            errors.append(f"Missing required dependency: {dep}")
    
    # Required dev dependencies
    dev_dependencies = package_data.get('devDependencies', {})
    required_dev_deps = ['jest', 'eslint']
    
    for dep in required_dev_deps:
        if dep not in dev_dependencies:
            errors.append(f"Missing required dev dependency: {dep}")
    
    # Check Jest configuration
    if 'jest' in package_data:
        jest_config = package_data['jest']
        if jest_config.get('testEnvironment') != 'node':
            errors.append("Jest testEnvironment should be 'node'")
    
    # Check for security vulnerabilities in dependencies
    vulnerable_packages = [
        'lodash@<4.17.21',
        'axios@<0.21.2',
        'node-fetch@<2.6.7'
    ]
    
    all_deps = {**dependencies, **dev_dependencies}
    for pkg_version in vulnerable_packages:
        pkg_name = pkg_version.split('@')[0]
        if pkg_name in all_deps:
            # This is a simplified check - in practice you'd use npm audit
            print(f"Warning: {pkg_name} may have security vulnerabilities")
    
    return errors

def main():
    """Main validation function."""
    if len(sys.argv) < 2:
        # Validate all package.json files in functions directory
        functions_dir = Path('functions')
        package_files = list(functions_dir.glob('*/package.json'))
    else:
        # Validate specific files passed as arguments
        package_files = [Path(arg) for arg in sys.argv[1:]]
    
    total_errors = 0
    
    for package_path in package_files:
        if not package_path.exists():
            print(f"❌ {package_path}: File not found")
            total_errors += 1
            continue
        
        errors = validate_package_json(package_path)
        
        if errors:
            print(f"❌ {package_path}:")
            for error in errors:
                print(f"  - {error}")
            total_errors += len(errors)
        else:
            print(f"✅ {package_path}: All checks passed")
    
    if total_errors > 0:
        print(f"\n❌ Validation failed with {total_errors} errors")
        return 1
    else:
        print(f"\n✅ All package.json files passed validation")
        return 0

if __name__ == '__main__':
    sys.exit(main())