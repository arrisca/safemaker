#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
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

print_deploy() {
    echo -e "${BLUE}[DEPLOY]${NC} $1"
}

# Initialize deployment report
DEPLOYMENT_REPORT="deployment-report.txt"
echo "Helm Deployment Report - $(date)" > $DEPLOYMENT_REPORT
echo "================================" >> $DEPLOYMENT_REPORT

print_info "Starting Helm deployment process..."

# Values file to use
VALUES_FILE="environments/${ENVIRONMENT}-values.yaml"

# Release name based on target and environment
get_release_name() {
    local target=$1
    echo "orca-${target}-${ENVIRONMENT}-${DATACENTER}"
}

# Namespace based on environment
get_namespace() {
    echo "orca-${ENVIRONMENT}"
}

RELEASE_NAME=$(get_release_name $DEPLOY_TARGET)
NAMESPACE=$(get_namespace)

print_info "Release name: $RELEASE_NAME"
print_info "Namespace: $NAMESPACE"
print_info "Deploy target: $DEPLOY_TARGET"
print_info "Action: $ACTION"

echo "Release: $RELEASE_NAME" >> $DEPLOYMENT_REPORT
echo "Namespace: $NAMESPACE" >> $DEPLOYMENT_REPORT
echo "Deploy Target: $DEPLOY_TARGET" >> $DEPLOYMENT_REPORT
echo "Action: $ACTION" >> $DEPLOYMENT_REPORT
echo "Environment: $ENVIRONMENT" >> $DEPLOYMENT_REPORT
echo "Datacenter: $DATACENTER" >> $DEPLOYMENT_REPORT
echo "---" >> $DEPLOYMENT_REPORT

# Function to ensure namespace exists
ensure_namespace() {
    local namespace=$1
    
    if ! kubectl get namespace $namespace >/dev/null 2>&1; then
        print_info "Creating namespace $namespace..."
        kubectl create namespace $namespace
        echo "Namespace $namespace created" >> $DEPLOYMENT_REPORT
    else
        print_info "Namespace $namespace already exists"
        echo "Namespace: EXISTS" >> $DEPLOYMENT_REPORT
    fi
}

# Function to create secrets
create_secrets() {
    local namespace=$1
    
    print_info "Creating/updating secrets..."
    
    # Create registry secret if not exists
    if ! kubectl get secret registry-secret -n $namespace >/dev/null 2>&1; then
        print_warning "Registry secret not found. Please ensure it's created manually."
        echo "Registry Secret: NOT_FOUND" >> $DEPLOYMENT_REPORT
    else
        print_info "✓ Registry secret exists"
        echo "Registry Secret: EXISTS" >> $DEPLOYMENT_REPORT
    fi
    
    # Create postgres secret if not exists
    if ! kubectl get secret postgres-secret -n $namespace >/dev/null 2>&1; then
        print_warning "PostgreSQL secret not found. Please ensure it's created manually."
        echo "PostgreSQL Secret: NOT_FOUND" >> $DEPLOYMENT_REPORT
    else
        print_info "✓ PostgreSQL secret exists"
        echo "PostgreSQL Secret: EXISTS" >> $DEPLOYMENT_REPORT
    fi
}

# Function to run helm install
run_helm_install() {
    local chart_path=$1
    local release_name=$2
    local namespace=$3
    
    print_deploy "Installing Helm chart..."
    
    # Create temporary values file
    TEMP_VALUES=$(mktemp)
    cp $VALUES_FILE $TEMP_VALUES
    
    # Enable the specific component if not umbrella
    if [ "$DEPLOY_TARGET" != "umbrella" ]; then
        echo "components:" >> $TEMP_VALUES
        echo "  $DEPLOY_TARGET:" >> $TEMP_VALUES
        echo "    enabled: true" >> $TEMP_VALUES
        # Disable other components
        for component in airflow spark postgresql redis; do
            if [ "$component" != "$DEPLOY_TARGET" ]; then
                echo "  $component:" >> $TEMP_VALUES
                echo "    enabled: false" >> $TEMP_VALUES
            fi
        done
    fi
    
    # Update dependencies
    print_info "Updating Helm dependencies..."
    helm dependency update $chart_path
    
    # Install chart
    if helm install $release_name $chart_path \
        --namespace $namespace \
        --values $TEMP_VALUES \
        --timeout 600s \
        --wait \
        --create-namespace 2>&1 | tee -a $DEPLOYMENT_REPORT; then
        print_info "✅ Helm install completed successfully"
        echo "INSTALL_STATUS: SUCCESS" >> $DEPLOYMENT_REPORT
    else
        print_error "❌ Helm install failed"
        echo "INSTALL_STATUS: FAILED" >> $DEPLOYMENT_REPORT
        rm -f $TEMP_VALUES
        return 1
    fi
    
    # Clean up
    rm -f $TEMP_VALUES
}

# Function to run helm upgrade
run_helm_upgrade() {
    local chart_path=$1
    local release_name=$2
    local namespace=$3
    
    print_deploy "Upgrading Helm chart..."
    
    # Create temporary values file
    TEMP_VALUES=$(mktemp)
    cp $VALUES_FILE $TEMP_VALUES
    
    # Enable the specific component if not umbrella
    if [ "$DEPLOY_TARGET" != "umbrella" ]; then
        echo "components:" >> $TEMP_VALUES
        echo "  $DEPLOY_TARGET:" >> $TEMP_VALUES
        echo "    enabled: true" >> $TEMP_VALUES
        # Disable other components
        for component in airflow spark postgresql redis; do
            if [ "$component" != "$DEPLOY_TARGET" ]; then
                echo "  $component:" >> $TEMP_VALUES
                echo "    enabled: false" >> $TEMP_VALUES
            fi
        done
    fi
    
    # Update dependencies
    print_info "Updating Helm dependencies..."
    helm dependency update $chart_path
    
    # Upgrade chart
    if helm upgrade $release_name $chart_path \
        --namespace $namespace \
        --values $TEMP_VALUES \
        --timeout 600s \
        --wait \
        --install \
        --reset-values 2>&1 | tee -a $DEPLOYMENT_REPORT; then
        print_info "✅ Helm upgrade completed successfully"
        echo "UPGRADE_STATUS: SUCCESS" >> $DEPLOYMENT_REPORT
    else
        print_error "❌ Helm upgrade failed"
        echo "UPGRADE_STATUS: FAILED" >> $DEPLOYMENT_REPORT
        rm -f $TEMP_VALUES
        return 1
    fi
    
    # Clean up
    rm -f $TEMP_VALUES
}

# Function to run helm uninstall
run_helm_uninstall() {
    local release_name=$1
    local namespace=$2
    
    print_deploy "Uninstalling Helm chart..."
    
    # Check if release exists
    if helm list -n $namespace | grep -q $release_name; then
        if helm uninstall $release_name \
            --namespace $namespace \
            --timeout 300s \
            --wait 2>&1 | tee -a $DEPLOYMENT_REPORT; then
            print_info "✅ Helm uninstall completed successfully"
            echo "UNINSTALL_STATUS: SUCCESS" >> $DEPLOYMENT_REPORT
        else
            print_error "❌ Helm uninstall failed"
            echo "UNINSTALL_STATUS: FAILED" >> $DEPLOYMENT_REPORT
            return 1
        fi
    else
        print_warning "Release $release_name not found"
        echo "UNINSTALL_STATUS: RELEASE_NOT_FOUND" >> $DEPLOYMENT_REPORT
    fi
}

# Function to show deployment status
show_deployment_status() {
    local namespace=$1
    local release_name=$2
    
    print_info "Showing deployment status..."
    echo "Deployment Status:" >> $DEPLOYMENT_REPORT
    
    # Get release status
    if helm list -n $namespace | grep -q $release_name; then
        helm status $release_name -n $namespace >> $DEPLOYMENT_REPORT 2>&1 || true
        echo "---" >> $DEPLOYMENT_REPORT
        
        # Get pods status
        print_info "Pod status:"
        kubectl get pods -n $namespace -l app.kubernetes.io/instance=$release_name >> $DEPLOYMENT_REPORT 2>&1 || true
        echo "---" >> $DEPLOYMENT_REPORT
        
        # Get services
        print_info "Service status:"
        kubectl get svc -n $namespace -l app.kubernetes.io/instance=$release_name >> $DEPLOYMENT_REPORT 2>&1 || true
        echo "---" >> $DEPLOYMENT_REPORT
        
        # Get ingress/routes
        print_info "Ingress/Route status:"
        kubectl get ingress -n $namespace -l app.kubernetes.io/instance=$release_name >> $DEPLOYMENT_REPORT 2>&1 || true
        oc get routes -n $namespace -l app.kubernetes.io/instance=$release_name >> $DEPLOYMENT_REPORT 2>&1 || true
        
    else
        echo "Release not found" >> $DEPLOYMENT_REPORT
    fi
}

# Function to validate deployment
validate_deployment() {
    local namespace=$1
    local release_name=$2
    
    print_info "Validating deployment..."
    echo "Validation Results:" >> $DEPLOYMENT_REPORT
    
    # Check if all pods are running
    PENDING_PODS=$(kubectl get pods -n $namespace -l app.kubernetes.io/instance=$release_name --field-selector=status.phase!=Running --no-headers 2>/dev/null | wc -l)
    
    if [ $PENDING_PODS -eq 0 ]; then
        print_info "✅ All pods are running"
        echo "Pod Status: ALL_RUNNING" >> $DEPLOYMENT_REPORT
    else
        print_warning "⚠ $PENDING_PODS pods are not running"
        echo "Pod Status: $PENDING_PODS NOT_RUNNING" >> $DEPLOYMENT_REPORT
    fi
    
    # Check services
    SERVICE_COUNT=$(kubectl get svc -n $namespace -l app.kubernetes.io/instance=$release_name --no-headers 2>/dev/null | wc -l)
    echo "Services Created: $SERVICE_COUNT" >> $DEPLOYMENT_REPORT
    
    # Check persistent volumes
    PVC_COUNT=$(kubectl get pvc -n $namespace --no-headers 2>/dev/null | wc -l)
    echo "PVCs Created: $PVC_COUNT" >> $DEPLOYMENT_REPORT
}

# Main execution
print_info "Ensuring namespace exists..."
ensure_namespace $NAMESPACE

print_info "Creating/checking secrets..."
create_secrets $NAMESPACE

# Execute based on action
case $ACTION in
    "install")
        case $DEPLOY_TARGET in
            "umbrella")
                run_helm_install "." $RELEASE_NAME $NAMESPACE
                ;;
            "airflow"|"spark"|"postgres")
                if [ -d "charts/$DEPLOY_TARGET" ]; then
                    run_helm_install "charts/$DEPLOY_TARGET" $RELEASE_NAME $NAMESPACE
                else
                    print_info "Using umbrella chart with $DEPLOY_TARGET component..."
                    run_helm_install "." $RELEASE_NAME $NAMESPACE
                fi
                ;;
            *)
                print_error "Unknown DEPLOY_TARGET: $DEPLOY_TARGET"
                exit 1
                ;;
        esac
        ;;
    "upgrade")
        case $DEPLOY_TARGET in
            "umbrella")
                run_helm_upgrade "." $RELEASE_NAME $NAMESPACE
                ;;
            "airflow"|"spark"|"postgres")
                if [ -d "charts/$DEPLOY_TARGET" ]; then
                    run_helm_upgrade "charts/$DEPLOY_TARGET" $RELEASE_NAME $NAMESPACE
                else
                    print_info "Using umbrella chart with $DEPLOY_TARGET component..."
                    run_helm_upgrade "." $RELEASE_NAME $NAMESPACE
                fi
                ;;
            *)
                print_error "Unknown DEPLOY_TARGET: $DEPLOY_TARGET"
                exit 1
                ;;
        esac
        ;;
    "uninstall")
        run_helm_uninstall $RELEASE_NAME $NAMESPACE
        ;;
    *)
        print_error "Unknown ACTION: $ACTION"
        exit 1
        ;;
esac

# Show deployment status
if [ "$ACTION" != "uninstall" ]; then
    show_deployment_status $NAMESPACE $RELEASE_NAME
    validate_deployment $NAMESPACE $RELEASE_NAME
fi

# Summary
echo "================================" >> $DEPLOYMENT_REPORT
echo "Deployment Summary:" >> $DEPLOYMENT_REPORT
echo "- Action: $ACTION" >> $DEPLOYMENT_REPORT
echo "- Release: $RELEASE_NAME" >> $DEPLOYMENT_REPORT
echo "- Namespace: $NAMESPACE" >> $DEPLOYMENT_REPORT
echo "- Target: $DEPLOY_TARGET" >> $DEPLOYMENT_REPORT
echo "- Environment: $ENVIRONMENT" >> $DEPLOYMENT_REPORT
echo "- Datacenter: $DATACENTER" >> $DEPLOYMENT_REPORT
echo "- Completed: $(date)" >> $DEPLOYMENT_REPORT

print_info "✅ Helm deployment process completed!"
echo "📋 Review the deployment report: $DEPLOYMENT_REPORT"