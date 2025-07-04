# Orca Chart Project Structure

This is the complete folder structure for the production-ready GitLab CI/CD pipeline for deploying the Orca Chart Helm umbrella chart.

```
orca-chart/
├── .gitlab-ci.yml                    # Main GitLab CI/CD pipeline configuration
├── Chart.yaml                        # Helm umbrella chart definition
├── values.yaml                       # Default values for all components
├── README.md                         # Main project documentation
│
├── charts/                           # Sub-charts directory
│   ├── airflow/                     # Apache Airflow chart
│   │   ├── Chart.yaml               # Airflow chart definition
│   │   └── values.yaml              # Airflow default values
│   ├── spark/                       # Apache Spark chart
│   │   ├── Chart.yaml               # Spark chart definition
│   │   └── values.yaml              # Spark default values
│   └── postgres/                    # PostgreSQL chart
│       ├── Chart.yaml               # PostgreSQL chart definition
│       └── values.yaml              # PostgreSQL default values
│
├── environments/                     # Environment-specific configurations
│   ├── dev-values.yaml              # Development environment values
│   ├── uat-values.yaml              # UAT environment values
│   └── prod-values.yaml             # Production environment values
│
├── terraform/                       # Infrastructure as Code
│   ├── main.tf                      # Main Terraform configuration
│   ├── variables.tf                 # Terraform variables
│   └── outputs.tf                   # Terraform outputs
│
├── scripts/                         # Utility scripts
│   ├── validate_inputs.sh           # Input validation script
│   ├── helm_lint.sh                 # Helm linting script
│   ├── helm_diff.sh                 # Helm diff script
│   ├── helm_deploy.sh               # Helm deployment script
│   ├── helm_rollback.sh             # Helm rollback script
│   └── cleanup.sh                   # Cleanup script
│
└── docs/                            # Documentation
    ├── gitlab-variables.md          # GitLab CI/CD variables guide
    ├── secrets-template.yaml        # Kubernetes secrets template
    └── deployment-guide.md          # Complete deployment guide
```

## Key Features Implemented

### ✅ GitLab CI/CD Pipeline (.gitlab-ci.yml)
- **Multi-stage pipeline**: validate → terraform → lint → diff → deploy → approval → cleanup
- **Input validation**: Supports DEPLOY_TARGET (umbrella, airflow, spark, postgres), ENVIRONMENT (dev, uat, prod), DATACENTER (GL, SL), ACTION (install, upgrade, uninstall, diff)
- **OpenShift support**: Configured for OpenShift container platform deployment
- **Manual approval**: Required for production deployments
- **Reusable YAML anchors**: Avoid duplication and improve maintainability
- **Conditional execution**: Each stage runs based on deployment target and action

### ✅ Terraform Infrastructure (terraform/)
- **PostgreSQL provisioning**: Complete Azure PostgreSQL Flexible Server setup
- **Remote state management**: Configured for Azure backend
- **Environment-specific**: Variables for dev/uat/prod environments
- **Security**: Private networking, DNS zones, and security configurations
- **Outputs**: Database connection details for Helm deployments

### ✅ Helm Chart Structure
- **Umbrella chart**: Main chart that orchestrates all sub-components
- **Sub-charts**: Individual charts for Airflow, Spark, and PostgreSQL
- **Environment values**: Separate values files for each environment
- **Resource scaling**: Appropriate resources for each environment
- **OpenShift compatibility**: Security contexts and route configurations

### ✅ Utility Scripts (scripts/)
- **validate_inputs.sh**: Comprehensive input validation with colored output
- **helm_lint.sh**: Chart linting with template validation
- **helm_diff.sh**: Shows deployment differences with approval workflow
- **helm_deploy.sh**: Handles install, upgrade, uninstall operations
- **helm_rollback.sh**: Automated rollback capabilities
- **cleanup.sh**: Resource cleanup and notification system

### ✅ Environment Configuration
- **Development**: Minimal resources, basic monitoring, single replicas
- **UAT**: Production-like setup with moderate resources, SSL/TLS
- **Production**: Full HA setup, autoscaling, monitoring, backup, disaster recovery

### ✅ Security & Best Practices
- **Secrets management**: External secrets with existing secret references
- **RBAC**: Role-based access control configurations
- **Network policies**: Security configurations for production
- **Image security**: Private registry support with pull secrets
- **Security contexts**: Non-root users and proper file permissions

### ✅ Documentation
- **Comprehensive README**: Project overview and usage instructions
- **GitLab variables guide**: Step-by-step variable configuration
- **Deployment guide**: Complete deployment procedures and troubleshooting
- **Secrets template**: Ready-to-use Kubernetes secrets

## Usage Examples

### Deploy Full Stack to Development
```bash
# GitLab CI/CD Variables:
DEPLOY_TARGET=umbrella
ENVIRONMENT=dev
DATACENTER=GL
ACTION=install
```

### Deploy Only Airflow to Production
```bash
# GitLab CI/CD Variables:
DEPLOY_TARGET=airflow
ENVIRONMENT=prod
DATACENTER=GL
ACTION=upgrade
```

### Preview Changes (Dry Run)
```bash
# GitLab CI/CD Variables:
DEPLOY_TARGET=umbrella
ENVIRONMENT=uat
DATACENTER=GL
ACTION=diff
```

## Ready for Production

This implementation provides:
- ✅ **Security**: Proper secrets management, RBAC, network policies
- ✅ **Scalability**: Environment-specific resource configurations
- ✅ **Reliability**: Health checks, rollback procedures, monitoring
- ✅ **Maintainability**: Modular structure, comprehensive documentation
- ✅ **Compliance**: Terraform infrastructure, audit trails, approval workflows
- ✅ **Monitoring**: Prometheus, Grafana, alerting configurations
- ✅ **Disaster Recovery**: Backup procedures, cross-region replication

The pipeline is production-ready and follows GitLab CI/CD best practices with proper separation of concerns, security controls, and operational procedures.