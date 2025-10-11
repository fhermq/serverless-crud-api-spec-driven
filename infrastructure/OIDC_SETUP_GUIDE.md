# OIDC Setup Guide for GitHub Actions

This guide explains how to set up OpenID Connect (OIDC) authentication for secure GitHub Actions deployments without storing AWS credentials in GitHub Secrets.

## Overview

OIDC provides a secure way to authenticate GitHub Actions with AWS using temporary credentials instead of long-lived access keys. This approach:

- ✅ Eliminates the need to store AWS credentials in GitHub Secrets
- ✅ Uses temporary credentials that expire within 1 hour
- ✅ Restricts access to specific repositories and branches
- ✅ Provides better security and audit trails
- ✅ Follows AWS security best practices

## Prerequisites

1. **AWS CLI configured** with permissions to create IAM roles and OIDC providers
2. **GitHub repository** where you want to enable OIDC authentication
3. **Admin access** to the GitHub repository to add secrets

## Quick Setup

### Step 1: Run the OIDC Setup Script

```bash
# Navigate to the infrastructure directory
cd infrastructure

# Run the setup script with your GitHub repository
./scripts/setup-oidc.sh --github-repo YOUR_ORG/YOUR_REPO

# For production deployment
./scripts/setup-oidc.sh --github-repo YOUR_ORG/YOUR_REPO --stage prod --region us-west-2
```

### Step 2: Add GitHub Repository Secret

After running the setup script, add the deployment role ARN to your GitHub repository secrets:

1. Go to your GitHub repository
2. Navigate to **Settings** → **Secrets and variables** → **Actions**
3. Click **New repository secret**
4. Add the secret:
   - **Name**: `AWS_DEPLOYMENT_ROLE_ARN`
   - **Value**: The ARN output from the setup script

### Step 3: Update GitHub Actions Workflow

Replace the AWS credentials configuration in your workflow:

**Before (using access keys):**
```yaml
- name: Configure AWS credentials
  uses: aws-actions/configure-aws-credentials@v4
  with:
    aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
    aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
    aws-region: us-east-1
```

**After (using OIDC):**
```yaml
permissions:
  id-token: write   # Required for OIDC
  contents: read    # Required for checkout

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout code
        uses: actions/checkout@v4
      
      - name: Configure AWS credentials via OIDC
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: ${{ secrets.AWS_DEPLOYMENT_ROLE_ARN }}
          role-session-name: GitHubActions-ServerlessCRUD
          aws-region: us-east-1
```

### Step 4: Remove Old Secrets

After confirming OIDC works, remove the old AWS credentials from GitHub Secrets:
- `AWS_ACCESS_KEY_ID`
- `AWS_SECRET_ACCESS_KEY`

## Manual Setup (Alternative)

If you prefer to set up OIDC manually:

### 1. Create OIDC Identity Provider

```bash
aws iam create-open-id-connect-provider \
  --url https://token.actions.githubusercontent.com \
  --client-id-list sts.amazonaws.com \
  --thumbprint-list 6938fd4d98bab03faadb97b34396831e3780aea1 1c58a3a8518e8759bf075b76b750d4f2df264fcd
```

### 2. Create IAM Role with Trust Policy

Create a trust policy file (`trust-policy.json`):

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::ACCOUNT_ID:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com",
          "token.actions.githubusercontent.com:sub": "repo:YOUR_ORG/YOUR_REPO:ref:refs/heads/main"
        }
      }
    }
  ]
}
```

Create the role:

```bash
aws iam create-role \
  --role-name GitHubActions-ServerlessCRUD-DeployRole \
  --assume-role-policy-document file://trust-policy.json \
  --max-session-duration 3600
```

### 3. Attach Deployment Permissions

The CloudFormation template includes comprehensive deployment permissions. You can also create a custom policy with minimal required permissions.

## Security Configuration

### Trust Policy Restrictions

The OIDC trust policy is configured with the following restrictions:

- **Repository**: Limited to the specific GitHub repository you specify
- **Branch**: Limited to the specified branch (default: `main`)
- **Audience**: Limited to `sts.amazonaws.com`
- **Session Duration**: Maximum 1 hour

### Deployment Permissions

The deployment role includes permissions for:

- ✅ CloudFormation stack operations
- ✅ Lambda function management
- ✅ API Gateway configuration
- ✅ IAM role management (with conditions)
- ✅ S3 access for SAM artifacts
- ✅ CloudWatch and SNS for monitoring
- ✅ DynamoDB read access for validation

### Permission Boundaries

All permissions are scoped to resources with the project naming convention:
- Stack names: `${ProjectName}-${Stage}-*`
- Lambda functions: `${ProjectName}-${Stage}-*`
- IAM roles: `${ProjectName}-${Stage}-*`

## Troubleshooting

### Common Issues

**1. "No OpenIDConnect provider found" error**
- Ensure the OIDC provider is created in the correct AWS account
- Verify the provider URL is exactly: `https://token.actions.githubusercontent.com`

**2. "Not authorized to perform sts:AssumeRoleWithWebIdentity" error**
- Check the trust policy repository and branch restrictions
- Ensure the GitHub repository format is correct: `owner/repo`
- Verify the workflow has `id-token: write` permissions

**3. "Access denied" during deployment**
- Check that the deployment role has sufficient permissions
- Verify the role can pass execution roles to Lambda functions
- Ensure CloudFormation permissions are correctly configured

**4. "Invalid thumbprint" error**
- GitHub's certificate thumbprints may change over time
- Update the thumbprint list in the OIDC provider configuration

### Validation Steps

1. **Test OIDC Authentication**:
   ```yaml
   - name: Verify OIDC authentication
     run: aws sts get-caller-identity
   ```

2. **Check Role Permissions**:
   ```bash
   aws iam simulate-principal-policy \
     --policy-source-arn arn:aws:iam::ACCOUNT:role/ROLE_NAME \
     --action-names cloudformation:CreateStack \
     --resource-arns arn:aws:cloudformation:us-east-1:ACCOUNT:stack/test-stack
   ```

3. **Monitor CloudTrail**:
   - Check CloudTrail logs for OIDC authentication events
   - Look for `AssumeRoleWithWebIdentity` API calls

## Multi-Branch Setup

To allow deployments from multiple branches, update the trust policy:

```json
{
  "StringLike": {
    "token.actions.githubusercontent.com:sub": [
      "repo:YOUR_ORG/YOUR_REPO:ref:refs/heads/main",
      "repo:YOUR_ORG/YOUR_REPO:ref:refs/heads/develop",
      "repo:YOUR_ORG/YOUR_REPO:ref:refs/heads/feature/*"
    ]
  }
}
```

## Environment-Specific Roles

For production environments, consider creating separate OIDC roles:

```bash
# Development role (more permissive)
./scripts/setup-oidc.sh --github-repo YOUR_ORG/YOUR_REPO --stage dev --github-branch develop

# Production role (restricted)
./scripts/setup-oidc.sh --github-repo YOUR_ORG/YOUR_REPO --stage prod --github-branch main
```

## Best Practices

1. **Use separate roles per environment** (dev, staging, prod)
2. **Restrict branches** in the trust policy
3. **Monitor CloudTrail** for OIDC authentication events
4. **Regularly rotate thumbprints** if GitHub updates certificates
5. **Use least privilege permissions** for deployment roles
6. **Test OIDC setup** in development before production
7. **Document role ARNs** for team members

## Migration from Access Keys

1. Set up OIDC authentication alongside existing access keys
2. Test OIDC in a development environment
3. Update workflows to use OIDC
4. Verify deployments work correctly
5. Remove access key secrets from GitHub
6. Disable or delete the old IAM user

## Support

For issues with OIDC setup:

1. Check the troubleshooting section above
2. Review AWS CloudTrail logs for authentication events
3. Validate IAM policies and trust relationships
4. Test with minimal permissions first
5. Consult AWS documentation for OIDC with GitHub Actions

## References

- [AWS Documentation: Creating OpenID Connect identity providers](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles_providers_create_oidc.html)
- [GitHub Documentation: Configuring OpenID Connect in Amazon Web Services](https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/configuring-openid-connect-in-amazon-web-services)
- [AWS Security Best Practices for OIDC](https://aws.amazon.com/blogs/security/use-iam-roles-to-connect-github-actions-to-actions-in-aws/)