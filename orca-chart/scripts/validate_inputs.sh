#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Initialize validation report
VALIDATION_REPORT="validation-report.txt"
echo "Validation Report - $(date)" > $VALIDATION_REPORT
echo "================================" >> $VALIDATION_REPORT

# Initialize validation status
VALIDATION_PASSED=true

print_info "Starting input validation..."

# Validate DEPLOY_TARGET
print_info "Validating DEPLOY_TARGET: $DEPLOY_TARGET"
case $DEPLOY_TARGET in
    "umbrella"|"airflow"|"spark"|"postgres")
        print_info "✓ Valid DEPLOY_TARGET: $DEPLOY_TARGET"
        echo "DEPLOY_TARGET: $DEPLOY_TARGET - VALID" >> $VALIDATION_REPORT
        ;;
    *)
        print_error "✗ Invalid DEPLOY_TARGET: $DEPLOY_TARGET"
        echo "DEPLOY_TARGET: $DEPLOY_TARGET - INVALID" >> $VALIDATION_REPORT
        echo "Valid options: umbrella, airflow, spark, postgres" >> $VALIDATION_REPORT
        VALIDATION_PASSED=false
        ;;
esac

# Validate ENVIRONMENT
print_info "Validating ENVIRONMENT: $ENVIRONMENT"
case $ENVIRONMENT in
    "dev"|"uat"|"prod")
        print_info "✓ Valid ENVIRONMENT: $ENVIRONMENT"
        echo "ENVIRONMENT: $ENVIRONMENT - VALID" >> $VALIDATION_REPORT
        ;;
    *)
        print_error "✗ Invalid ENVIRONMENT: $ENVIRONMENT"
        echo "ENVIRONMENT: $ENVIRONMENT - INVALID" >> $VALIDATION_REPORT
        echo "Valid options: dev, uat, prod" >> $VALIDATION_REPORT
        VALIDATION_PASSED=false
        ;;
esac

# Validate DATACENTER
print_info "Validating DATACENTER: $DATACENTER"
case $DATACENTER in
    "GL"|"SL")
        print_info "✓ Valid DATACENTER: $DATACENTER"
        echo "DATACENTER: $DATACENTER - VALID" >> $VALIDATION_REPORT
        ;;
    *)
        print_error "✗ Invalid DATACENTER: $DATACENTER"
        echo "DATACENTER: $DATACENTER - INVALID" >> $VALIDATION_REPORT
        echo "Valid options: GL, SL" >> $VALIDATION_REPORT
        VALIDATION_PASSED=false
        ;;
esac

# Validate ACTION
print_info "Validating ACTION: $ACTION"
case $ACTION in
    "install"|"upgrade"|"uninstall"|"diff"|"rollback")
        print_info "✓ Valid ACTION: $ACTION"
        echo "ACTION: $ACTION - VALID" >> $VALIDATION_REPORT
        ;;
    *)
        print_error "✗ Invalid ACTION: $ACTION"
        echo "ACTION: $ACTION - INVALID" >> $VALIDATION_REPORT
        echo "Valid options: install, upgrade, uninstall, diff, rollback" >> $VALIDATION_REPORT
        VALIDATION_PASSED=false
        ;;
esac

# Validate values file exists
VALUES_FILE="environments/${ENVIRONMENT}-values.yaml"
print_info "Validating values file: $VALUES_FILE"
if [ -f "$VALUES_FILE" ]; then
    print_info "✓ Values file exists: $VALUES_FILE"
    echo "VALUES_FILE: $VALUES_FILE - EXISTS" >> $VALIDATION_REPORT
else
    print_error "✗ Values file not found: $VALUES_FILE"
    echo "VALUES_FILE: $VALUES_FILE - NOT FOUND" >> $VALIDATION_REPORT
    VALIDATION_PASSED=false
fi

# Validate chart exists (if not umbrella)
if [ "$DEPLOY_TARGET" != "umbrella" ]; then
    CHART_PATH="charts/${DEPLOY_TARGET}"
    print_info "Validating chart path: $CHART_PATH"
    if [ -d "$CHART_PATH" ]; then
        print_info "✓ Chart directory exists: $CHART_PATH"
        echo "CHART_PATH: $CHART_PATH - EXISTS" >> $VALIDATION_REPORT
    else
        print_warning "⚠ Chart directory not found: $CHART_PATH"
        echo "CHART_PATH: $CHART_PATH - NOT FOUND (will use remote chart)" >> $VALIDATION_REPORT
    fi
fi

# Validate required environment variables for specific actions
if [ "$ACTION" == "install" ] || [ "$ACTION" == "upgrade" ]; then
    print_info "Validating required environment variables for deployment..."
    
    # Check OpenShift credentials
    if [ -z "$OPENSHIFT_SERVER" ]; then
        print_warning "⚠ OPENSHIFT_SERVER not set"
        echo "OPENSHIFT_SERVER: NOT SET" >> $VALIDATION_REPORT
    else
        print_info "✓ OPENSHIFT_SERVER is set"
        echo "OPENSHIFT_SERVER: SET" >> $VALIDATION_REPORT
    fi
    
    if [ -z "$OPENSHIFT_TOKEN" ]; then
        print_warning "⚠ OPENSHIFT_TOKEN not set"
        echo "OPENSHIFT_TOKEN: NOT SET" >> $VALIDATION_REPORT
    else
        print_info "✓ OPENSHIFT_TOKEN is set"
        echo "OPENSHIFT_TOKEN: SET" >> $VALIDATION_REPORT
    fi
    
    if [ -z "$OPENSHIFT_PROJECT" ]; then
        print_warning "⚠ OPENSHIFT_PROJECT not set"
        echo "OPENSHIFT_PROJECT: NOT SET" >> $VALIDATION_REPORT
    else
        print_info "✓ OPENSHIFT_PROJECT is set"
        echo "OPENSHIFT_PROJECT: SET" >> $VALIDATION_REPORT
    fi
fi

# Validate Terraform variables if PostgreSQL deployment
if [ "$DEPLOY_TARGET" == "postgres" ] || [ "$DEPLOY_TARGET" == "umbrella" ]; then
    print_info "Validating Terraform variables for PostgreSQL deployment..."
    
    if [ -z "$TF_VAR_resource_group" ]; then
        print_warning "⚠ TF_VAR_resource_group not set"
        echo "TF_VAR_resource_group: NOT SET" >> $VALIDATION_REPORT
    else
        print_info "✓ TF_VAR_resource_group is set"
        echo "TF_VAR_resource_group: SET" >> $VALIDATION_REPORT
    fi
    
    if [ -z "$TF_VAR_location" ]; then
        print_warning "⚠ TF_VAR_location not set"
        echo "TF_VAR_location: NOT SET" >> $VALIDATION_REPORT
    else
        print_info "✓ TF_VAR_location is set"
        echo "TF_VAR_location: SET" >> $VALIDATION_REPORT
    fi
    
    if [ -z "$TF_VAR_pg_password" ]; then
        print_warning "⚠ TF_VAR_pg_password not set"
        echo "TF_VAR_pg_password: NOT SET" >> $VALIDATION_REPORT
    else
        print_info "✓ TF_VAR_pg_password is set"
        echo "TF_VAR_pg_password: SET" >> $VALIDATION_REPORT
    fi
fi

# Validate Helm and kubectl versions
print_info "Validating tool versions..."
HELM_VERSION_CHECK=$(helm version --short 2>/dev/null || echo "not installed")
KUBECTL_VERSION_CHECK=$(kubectl version --client --short 2>/dev/null || echo "not installed")

echo "HELM_VERSION: $HELM_VERSION_CHECK" >> $VALIDATION_REPORT
echo "KUBECTL_VERSION: $KUBECTL_VERSION_CHECK" >> $VALIDATION_REPORT

# Final validation result
echo "================================" >> $VALIDATION_REPORT
if [ "$VALIDATION_PASSED" = true ]; then
    print_info "✅ All validations passed!"
    echo "VALIDATION_RESULT: PASSED" >> $VALIDATION_REPORT
    exit 0
else
    print_error "❌ Validation failed!"
    echo "VALIDATION_RESULT: FAILED" >> $VALIDATION_REPORT
    exit 1
fi