# GitLab CI/CD Variables Configuration

This document outlines the required and optional variables for the Orca Chart GitLab CI/CD pipeline.

## Required Variables

### Deployment Configuration
Set these in GitLab Project > Settings > CI/CD > Variables:

```bash
# Core deployment variables
DEPLOY_TARGET: "umbrella"          # umbrella, airflow, spark, postgres
ENVIRONMENT: "dev"                 # dev, uat, prod
DATACENTER: "GL"                   # GL, SL
ACTION: "install"                  # install, upgrade, uninstall, diff, rollback

# OpenShift Configuration
OPENSHIFT_SERVER: "https://api.your-openshift-cluster.com:6443"
OPENSHIFT_TOKEN: "sha256~your-openshift-token-here"
OPENSHIFT_PROJECT: "orca-dev"

# Container Registry
REGISTRY_URL: "your-registry.azurecr.io"
REGISTRY_USERNAME: "your-registry-username"
REGISTRY_PASSWORD: "your-registry-password"  # Mark as Protected and Masked
```

### Terraform Variables (for PostgreSQL)
```bash
# Azure Configuration
TF_VAR_resource_group: "orca-resources-rg"
TF_VAR_location: "East US"
TF_VAR_pg_password: "YourSecurePostgreSQLPassword123!"  # Mark as Protected and Masked

# Terraform Backend (if using remote state)
TF_BACKEND_STORAGE_ACCOUNT: "yourtfstateaccount"
TF_BACKEND_CONTAINER: "terraform-state"
TF_BACKEND_KEY: "orca-chart.tfstate"
TF_BACKEND_RESOURCE_GROUP: "terraform-state-rg"
```

## Optional Variables

### Tool Versions
```bash
HELM_VERSION: "3.14.0"
KUBECTL_VERSION: "1.29.0"
TERRAFORM_VERSION: "1.6.0"
```

### Notification Configuration
```bash
# Slack Notifications
SLACK_WEBHOOK: "https://hooks.slack.com/services/YOUR/SLACK/WEBHOOK"

# Email Notifications
EMAIL_RECIPIENTS: "devops@your-domain.com,team@your-domain.com"
```

### Advanced Configuration
```bash
# Rollback Configuration
ROLLBACK_REVISION: "2"             # Specific revision to rollback to

# Debug Mode
HELM_DEBUG: "true"                 # Enable Helm debug logging
KUBECTL_VERBOSE: "true"            # Enable kubectl verbose output
```

## Variable Security Settings

When setting up variables in GitLab:

1. **Protected Variables**: Check this for production-only variables
2. **Masked Variables**: Check this for sensitive data (passwords, tokens)
3. **Environment Scope**: Set specific scopes for environment-specific variables

### Example Variable Configuration:

| Variable Name | Value | Protected | Masked | Environment Scope |
|---------------|-------|-----------|--------|-------------------|
| OPENSHIFT_TOKEN | sha256~... | ✓ | ✓ | All |
| TF_VAR_pg_password | SecurePass123! | ✓ | ✓ | production |
| DEPLOY_TARGET | umbrella | ✗ | ✗ | All |
| ENVIRONMENT | prod | ✓ | ✗ | production |

## Environment-Specific Variables

### Development Environment
```bash
ENVIRONMENT: "dev"
OPENSHIFT_PROJECT: "orca-dev"
TF_VAR_resource_group: "orca-dev-rg"
```

### UAT Environment
```bash
ENVIRONMENT: "uat"
OPENSHIFT_PROJECT: "orca-uat"
TF_VAR_resource_group: "orca-uat-rg"
```

### Production Environment
```bash
ENVIRONMENT: "prod"
OPENSHIFT_PROJECT: "orca-prod"
TF_VAR_resource_group: "orca-prod-rg"
```

## Setting Variables via GitLab UI

1. Navigate to your GitLab project
2. Go to **Settings** > **CI/CD**
3. Expand **Variables** section
4. Click **Add variable**
5. Enter the variable name and value
6. Set appropriate flags (Protected/Masked)
7. Choose environment scope if needed
8. Click **Add variable**

## Validation

The pipeline includes a validation stage that checks for:
- Required variables are set
- Values are within acceptable ranges
- Environment-specific configurations are valid

If validation fails, the pipeline will stop and provide detailed error messages.