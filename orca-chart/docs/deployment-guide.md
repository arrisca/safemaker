# Orca Chart Deployment Guide

This guide provides step-by-step instructions for deploying the Orca Chart using GitLab CI/CD.

## Prerequisites

1. **GitLab Project Setup**
   - Repository with the Orca Chart code
   - GitLab Runner with Docker executor
   - Necessary permissions to set CI/CD variables

2. **OpenShift Cluster**
   - Access to OpenShift cluster
   - Service account with deployment permissions
   - Sufficient cluster resources

3. **Azure Subscription** (for PostgreSQL)
   - Azure subscription with appropriate permissions
   - Resource group for infrastructure
   - Storage account for Terraform state (optional)

4. **Container Registry**
   - Access to container registry (ACR, Docker Hub, etc.)
   - Pre-built images for Airflow, Spark, and supporting services

## Initial Setup

### 1. Configure GitLab Variables

Navigate to your GitLab project and set the required variables:

```bash
# In GitLab Project > Settings > CI/CD > Variables
OPENSHIFT_SERVER: "https://api.your-openshift-cluster.com:6443"
OPENSHIFT_TOKEN: "sha256~your-service-account-token"
REGISTRY_URL: "your-registry.azurecr.io"
REGISTRY_USERNAME: "your-registry-username"
REGISTRY_PASSWORD: "your-registry-password"
TF_VAR_resource_group: "orca-resources-rg"
TF_VAR_location: "East US"
TF_VAR_pg_password: "YourSecurePassword123!"
```

### 2. Create OpenShift Project

```bash
oc new-project orca-dev
oc new-project orca-uat
oc new-project orca-prod
```

### 3. Create Required Secrets

Apply the secrets template with your values:

```bash
# Create registry secret
oc create secret docker-registry registry-secret \
  --docker-server=your-registry.azurecr.io \
  --docker-username=your-username \
  --docker-password=your-password \
  -n orca-dev

# Create PostgreSQL secret
oc create secret generic postgres-secret \
  --from-literal=POSTGRES_PASSWORD=YourSecurePassword123! \
  -n orca-dev
```

## Deployment Scenarios

### Scenario 1: Deploy Full Stack to Development

1. **Set Pipeline Variables:**
   ```bash
   DEPLOY_TARGET: umbrella
   ENVIRONMENT: dev
   DATACENTER: GL
   ACTION: install
   ```

2. **Run Pipeline:**
   - Navigate to GitLab CI/CD > Pipelines
   - Click "Run Pipeline"
   - Set the variables above
   - Click "Run Pipeline"

3. **Monitor Progress:**
   - Watch pipeline stages execute
   - Review logs for any issues
   - Validate deployment in OpenShift console

### Scenario 2: Upgrade Airflow in UAT

1. **Set Pipeline Variables:**
   ```bash
   DEPLOY_TARGET: airflow
   ENVIRONMENT: uat
   DATACENTER: GL
   ACTION: upgrade
   ```

2. **Review Changes:**
   - Pipeline will run diff stage first
   - Review proposed changes
   - Approve to proceed with deployment

### Scenario 3: Production Deployment

1. **Set Pipeline Variables:**
   ```bash
   DEPLOY_TARGET: umbrella
   ENVIRONMENT: prod
   DATACENTER: GL
   ACTION: install
   ```

2. **Pre-Deployment Checks:**
   - Ensure all tests pass in UAT
   - Review security configurations
   - Verify backup procedures

3. **Deploy with Approval:**
   - Pipeline will pause at approval stage
   - Review deployment plan
   - Manually approve for production deployment

## Pipeline Stages Explained

### 1. Validate Stage
- Validates input parameters
- Checks file existence
- Verifies environment configuration

**Common Issues:**
- Invalid DEPLOY_TARGET value
- Missing values files
- Incorrect environment variables

### 2. Terraform Stage
- Provisions PostgreSQL infrastructure
- Manages Azure resources
- Updates Terraform state

**Common Issues:**
- Azure authentication failure
- Resource group doesn't exist
- Insufficient permissions

### 3. Lint Stage
- Validates Helm chart syntax
- Checks best practices
- Verifies template rendering

**Common Issues:**
- YAML syntax errors
- Missing required values
- Template rendering failures

### 4. Diff Stage
- Shows deployment differences
- Provides dry-run preview
- Requires manual approval

**Review Points:**
- Resource changes
- Configuration updates
- Version updates

### 5. Deploy Stage
- Executes Helm deployment
- Waits for completion
- Validates deployment status

**Monitoring:**
- Pod startup progress
- Service availability
- Ingress configuration

### 6. Cleanup Stage
- Removes temporary files
- Sends notifications
- Archives reports

## Post-Deployment Verification

### 1. Check Pod Status
```bash
oc get pods -n orca-dev
oc describe pod <pod-name> -n orca-dev
```

### 2. Verify Services
```bash
oc get svc -n orca-dev
oc get routes -n orca-dev
```

### 3. Check Logs
```bash
oc logs -f deployment/airflow-webserver -n orca-dev
oc logs -f deployment/spark-master -n orca-dev
```

### 4. Access Applications
- Airflow: Navigate to the route URL
- Spark UI: Access through service port-forward
- Database: Connect using service endpoint

## Troubleshooting

### Common Deployment Issues

1. **Image Pull Errors**
   ```bash
   # Check image pull secret
   oc get secret registry-secret -n orca-dev -o yaml
   
   # Verify image exists
   oc describe pod <failing-pod> -n orca-dev
   ```

2. **Persistent Volume Issues**
   ```bash
   # Check PVC status
   oc get pvc -n orca-dev
   
   # Check storage class
   oc get storageclass
   ```

3. **Network Connectivity**
   ```bash
   # Check service endpoints
   oc get endpoints -n orca-dev
   
   # Test connectivity
   oc exec -it <pod-name> -n orca-dev -- curl http://service-name:port
   ```

### Pipeline Failures

1. **Validation Failures**
   - Check variable values
   - Verify file paths
   - Review error messages

2. **Terraform Failures**
   - Check Azure permissions
   - Verify resource group exists
   - Review Terraform logs

3. **Helm Failures**
   - Check chart syntax
   - Verify values files
   - Review Helm logs

## Rollback Procedures

### Automatic Rollback
```bash
# Set pipeline variables for rollback
DEPLOY_TARGET: umbrella
ENVIRONMENT: prod
ACTION: rollback
ROLLBACK_REVISION: 2  # Optional: specific revision
```

### Manual Rollback
```bash
# List release history
helm history orca-umbrella-prod-GL -n orca-prod

# Rollback to previous version
helm rollback orca-umbrella-prod-GL 2 -n orca-prod
```

## Best Practices

### Security
1. Use protected variables for sensitive data
2. Enable network policies in production
3. Implement proper RBAC
4. Regular security scans of images

### Monitoring
1. Set up alerts for critical services
2. Monitor resource usage
3. Implement log aggregation
4. Regular backup verification

### Maintenance
1. Regular dependency updates
2. Security patch management
3. Capacity planning
4. Disaster recovery testing

## Support and Escalation

1. **Level 1**: Check troubleshooting guide
2. **Level 2**: Review GitLab pipeline logs
3. **Level 3**: Contact DevOps team
4. **Level 4**: Engage vendor support

For urgent issues:
- Slack: #devops-alerts
- Email: devops-oncall@your-domain.com
- Phone: Emergency hotline

## Additional Resources

- [GitLab CI/CD Documentation](https://docs.gitlab.com/ee/ci/)
- [Helm Documentation](https://helm.sh/docs/)
- [OpenShift Documentation](https://docs.openshift.com/)
- [Terraform Azure Provider](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs)