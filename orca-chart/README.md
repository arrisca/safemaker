# Orca Chart - Helm Umbrella Chart for Data Platform

This repository contains a production-ready GitLab CI/CD pipeline for deploying the Orca Chart, a Helm umbrella chart that manages Airflow, Spark, and PostgreSQL deployments on OpenShift.

## Overview

The Orca Chart is designed to deploy a complete data platform stack including:
- **Apache Airflow** - Workflow orchestration
- **Apache Spark** - Big data processing
- **PostgreSQL** - Primary database
- **Redis** - Message broker for Airflow

## Repository Structure

```
orca-chart/
├── .gitlab-ci.yml              # GitLab CI/CD pipeline configuration
├── Chart.yaml                  # Helm umbrella chart definition
├── values.yaml                 # Default values for all components
├── charts/                     # Sub-charts directory
│   ├── airflow/               # Airflow chart (if customized)
│   ├── spark/                 # Spark chart (if customized)
│   └── postgres/              # PostgreSQL chart (if customized)
├── environments/              # Environment-specific configurations
│   ├── dev-values.yaml        # Development environment values
│   ├── uat-values.yaml        # UAT environment values
│   └── prod-values.yaml       # Production environment values
├── terraform/                 # Infrastructure as Code
│   ├── main.tf               # Main Terraform configuration
│   ├── variables.tf          # Terraform variables
│   └── outputs.tf            # Terraform outputs
├── scripts/                   # Utility scripts
│   ├── validate_inputs.sh     # Input validation script
│   ├── helm_lint.sh          # Helm linting script
│   ├── helm_diff.sh          # Helm diff script
│   ├── helm_deploy.sh        # Helm deployment script
│   ├── helm_rollback.sh      # Helm rollback script
│   └── cleanup.sh            # Cleanup script
└── README.md                 # This file
```

## Pipeline Variables

The GitLab CI/CD pipeline supports the following variables that can be set through the GitLab UI:

### Required Variables
- `DEPLOY_TARGET`: Target component to deploy
  - `umbrella`: Deploy all components
  - `airflow`: Deploy only Airflow
  - `spark`: Deploy only Spark
  - `postgres`: Deploy only PostgreSQL

- `ENVIRONMENT`: Target environment
  - `dev`: Development environment
  - `uat`: User Acceptance Testing environment
  - `prod`: Production environment

- `DATACENTER`: Target datacenter
  - `GL`: Primary datacenter
  - `SL`: Secondary datacenter

- `ACTION`: Deployment action
  - `install`: Install new deployment
  - `upgrade`: Upgrade existing deployment
  - `uninstall`: Remove deployment
  - `diff`: Show differences (dry-run)
  - `rollback`: Rollback to previous version

### OpenShift Configuration
- `OPENSHIFT_SERVER`: OpenShift cluster API server URL
- `OPENSHIFT_TOKEN`: OpenShift authentication token
- `OPENSHIFT_PROJECT`: OpenShift project/namespace

### Terraform Variables (for PostgreSQL)
- `TF_VAR_resource_group`: Azure resource group name
- `TF_VAR_location`: Azure region (e.g., "East US")
- `TF_VAR_pg_password`: PostgreSQL administrator password

### Optional Variables
- `HELM_VERSION`: Helm version to use (default: 3.14.0)
- `KUBECTL_VERSION`: kubectl version to use (default: 1.29.0)
- `TERRAFORM_VERSION`: Terraform version to use (default: 1.6.0)

## Pipeline Stages

### 1. Validate
- Validates all input parameters
- Checks for required files and configurations
- Verifies chart structure and syntax

### 2. Terraform
- Provisions PostgreSQL infrastructure using Terraform
- Only runs when deploying PostgreSQL or umbrella chart
- Manages remote state and infrastructure lifecycle

### 3. Lint
- Runs Helm lint on selected charts
- Validates YAML syntax and Helm templates
- Checks for best practices and common issues

### 4. Diff
- Shows differences between current and desired state
- Provides dry-run preview of changes
- Requires manual approval before proceeding

### 5. Deploy
- Deploys the selected chart to OpenShift
- Handles install, upgrade, and uninstall operations
- Waits for deployment completion and validates status

### 6. Approval
- Manual approval gate for production deployments
- Allows review before final deployment
- Skipped for non-production environments

### 7. Cleanup
- Cleans up temporary files and resources
- Sends notifications about deployment status
- Archives reports for production deployments

## Usage Examples

### Deploy Full Stack to Development
```bash
# Set variables in GitLab CI/CD interface:
DEPLOY_TARGET=umbrella
ENVIRONMENT=dev
DATACENTER=GL
ACTION=install
```

### Deploy Only Airflow to UAT
```bash
# Set variables in GitLab CI/CD interface:
DEPLOY_TARGET=airflow
ENVIRONMENT=uat
DATACENTER=GL
ACTION=upgrade
```

### Preview Changes for Production
```bash
# Set variables in GitLab CI/CD interface:
DEPLOY_TARGET=umbrella
ENVIRONMENT=prod
DATACENTER=GL
ACTION=diff
```

## Environment Configuration

Each environment has its own values file in the `environments/` directory:

- **Development** (`dev-values.yaml`): Minimal resources, basic monitoring
- **UAT** (`uat-values.yaml`): Production-like setup with moderate resources
- **Production** (`prod-values.yaml`): Full production setup with HA, monitoring, and backup

## Security Considerations

1. **Secrets Management**: Use GitLab CI/CD variables for sensitive information
2. **RBAC**: Implement proper role-based access control
3. **Network Policies**: Enable network policies in production
4. **Image Security**: Use trusted container registries
5. **Backup**: Regular backups of persistent data

## Monitoring and Observability

The production configuration includes:
- **Prometheus**: Metrics collection
- **Grafana**: Visualization and dashboards
- **Alertmanager**: Alert routing and notification
- **Logging**: Centralized log collection

## Disaster Recovery

Production deployments include:
- Cross-region replication
- Automated backups
- Point-in-time recovery capabilities
- Disaster recovery procedures

## Prerequisites

1. **GitLab Runner**: With Docker executor
2. **OpenShift Cluster**: Target deployment platform
3. **Azure Subscription**: For PostgreSQL infrastructure
4. **Container Registry**: For storing Docker images
5. **Helm Charts**: Access to required chart repositories

## Customization

### Adding New Components
1. Add chart dependency in `Chart.yaml`
2. Update `values.yaml` with component configuration
3. Create component-specific values in environment files
4. Update validation scripts if needed

### Modifying Environments
1. Edit environment-specific values files
2. Update Terraform variables as needed
3. Modify pipeline stages if required
4. Test changes in development first

## Troubleshooting

### Common Issues

1. **Permission Denied**: Check OpenShift token and project permissions
2. **Chart Not Found**: Verify chart repositories are accessible
3. **Resource Limits**: Check cluster resource availability
4. **Network Issues**: Verify network policies and ingress configuration

### Debug Mode
Enable debug logging by setting:
```bash
HELM_DEBUG=true
KUBECTL_VERBOSE=true
```

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test in development environment
5. Submit a pull request
6. Ensure all pipeline stages pass

## Support

For issues and questions:
- Create a GitLab issue
- Contact the DevOps team
- Check the troubleshooting guide
- Review pipeline logs

## License

This project is licensed under the Apache License 2.0 - see the LICENSE file for details.