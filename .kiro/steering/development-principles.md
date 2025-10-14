# Development Principles & Standards

## Core Philosophy
- **Less is More**: Minimal code, maximum value
- **SAM First**: Use AWS SAM patterns and best practices
- **Parametric Everything**: No hardcoded values, all configurable
- **Clean & Simple**: Readable, maintainable, straightforward solutions

## Infrastructure Standards

### SAM Templates
- Use AWS SAM syntax and conventions
- Leverage SAM built-in functions and transforms
- Keep templates focused and single-purpose
- Use CloudFormation exports/imports for cross-stack references

### Parameter Management
```json
// Standard parameter file structure
{
  "Parameters": {
    "ProjectName": "project-name",
    "Region": "us-east-1", 
    "Stage": "dev"
  }
}
```

### Deployment Scripts Pattern
```bash
# Standard script structure
STAGE=${1:-dev}

# Get parameters from JSON file
PARAM_FILE="parameters/${STAGE}.json"
if [[ -f "$PARAM_FILE" ]]; then
  PROJECT_NAME=$(jq -r '.Parameters.ProjectName // "default-name"' "$PARAM_FILE")
  REGION=$(jq -r '.Parameters.Region // "us-east-1"' "$PARAM_FILE")
else
  # Fallback defaults
  PROJECT_NAME="default-name"
  REGION="us-east-1"
fi

# Use variables consistently
STACK_NAME="$PROJECT_NAME-$STAGE-stacktype"
```

## Decision Making Process

### Before Starting Any Task
1. **Ask**: What's the simplest solution?
2. **Check**: Does this follow existing patterns?
3. **Validate**: Is this parametric and configurable?
4. **Confirm**: Does this align with SAM best practices?

### When I Start Overcomplicating
- **Stop immediately** when you say "less is more"
- **Ask for the minimal viable solution**
- **Reference existing working examples**
- **Focus on the core requirement only**

## Code Quality Standards

### Bash Scripts
- Use consistent parameter extraction pattern
- Include basic error handling (`set -e`)
- Provide clear output messages
- Follow existing script structure

### SAM Templates
- Use consistent naming conventions
- Leverage SAM transforms and built-ins
- Keep resource definitions clean and minimal
- Use parameters for all configurable values

### File Organization
- Follow established directory structure
- Use consistent naming patterns
- Keep related files together
- Maintain clear separation of concerns

## Interaction Guidelines

### When You Want to Redirect Me
- Say **"SAM approach"** - I'll focus on AWS SAM patterns
- Say **"Less is more"** - I'll simplify immediately
- Say **"Follow pattern X"** - I'll use existing examples
- Say **"Parametric"** - I'll ensure everything is configurable
- Say **"Clean up the mess"** - I'll delete unnecessary files and simplify

### What I Should Always Ask
- "What's the simplest approach?"
- "Should I follow the existing pattern in [file]?"
- "Do you want me to keep this minimal?"
- "Is this parametric enough?"
- "Are there any secrets that need secure handling?"
- "Should this use OIDC instead of stored credentials?"

## Success Metrics
- **Efficiency**: Fewer iterations to reach the goal
- **Simplicity**: Code that's easy to understand and maintain
- **Consistency**: Following established patterns
- **Cost-Effectiveness**: Minimal rework and refactoring

## Security Standards

### Secrets Management
- **Never commit secrets**: No API keys, passwords, tokens in code
- **Use AWS Secrets Manager**: For sensitive configuration
- **Use AWS Systems Manager Parameter Store**: For non-sensitive config
- **Environment variables**: For runtime configuration only
- **OIDC Authentication**: No long-lived AWS credentials

### GitHub Security
```bash
# Add to .gitignore
*.pem
*.key
.env
.env.local
secrets/
credentials/
```

### SAM Security Patterns
```yaml
# Use AWS::SecretsManager::Secret
DatabasePassword:
  Type: AWS::SecretsManager::Secret
  Properties:
    GenerateSecretString:
      SecretStringTemplate: '{"username": "admin"}'
      GenerateStringKey: 'password'
      
# Reference secrets in Lambda
Environment:
  Variables:
    DB_SECRET_ARN: !Ref DatabasePassword
```

### Script Security
```bash
# Never do this
AWS_ACCESS_KEY_ID="AKIA..." # ❌ NEVER

# Do this instead
aws sts get-caller-identity # ✅ Use IAM roles/OIDC
```

## Anti-Patterns to Avoid
- ❌ Creating complex abstractions when simple solutions exist
- ❌ Reinventing patterns instead of following existing ones
- ❌ Adding features not explicitly requested
- ❌ Hardcoding values instead of using parameters
- ❌ Overengineering solutions
- ❌ **Committing secrets, keys, or passwords**
- ❌ **Hardcoding credentials in code or templates**
- ❌ **Using long-lived AWS access keys**
- ❌ **Creating multiple files when one simple file works**
- ❌ **Building complex CI/CD when simple GitHub Actions work**
- ❌ **Adding contract testing frameworks when unit tests are sufficient**

## Reference Examples
- **Parameter Pattern**: `infrastructure/scripts/deploy.sh`
- **SAM Template**: `infrastructure/stacks/*.yaml`
- **Script Structure**: `infrastructure/scripts/cleanup.sh`

---
*This steering file should guide all development decisions to ensure efficient, clean, and maintainable solutions.*