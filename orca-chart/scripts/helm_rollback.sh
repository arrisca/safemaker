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

print_rollback() {
    echo -e "${BLUE}[ROLLBACK]${NC} $1"
}

# Initialize rollback report
ROLLBACK_REPORT="rollback-report.txt"
echo "Helm Rollback Report - $(date)" > $ROLLBACK_REPORT
echo "================================" >> $ROLLBACK_REPORT

print_info "Starting Helm rollback process..."

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

echo "Release: $RELEASE_NAME" >> $ROLLBACK_REPORT
echo "Namespace: $NAMESPACE" >> $ROLLBACK_REPORT
echo "Deploy Target: $DEPLOY_TARGET" >> $ROLLBACK_REPORT
echo "Environment: $ENVIRONMENT" >> $ROLLBACK_REPORT
echo "Datacenter: $DATACENTER" >> $ROLLBACK_REPORT
echo "---" >> $ROLLBACK_REPORT

# Function to show release history
show_release_history() {
    local release_name=$1
    local namespace=$2
    
    print_info "Showing release history for $release_name..."
    echo "Release History:" >> $ROLLBACK_REPORT
    
    if helm list -n $namespace | grep -q $release_name; then
        helm history $release_name -n $namespace --max 10 | tee -a $ROLLBACK_REPORT
    else
        print_error "Release $release_name not found"
        echo "Release not found" >> $ROLLBACK_REPORT
        return 1
    fi
}

# Function to get rollback revision
get_rollback_revision() {
    local release_name=$1
    local namespace=$2
    
    # If ROLLBACK_REVISION is set, use it
    if [ -n "$ROLLBACK_REVISION" ]; then
        echo $ROLLBACK_REVISION
        return 0
    fi
    
    # Otherwise, get the previous revision
    CURRENT_REVISION=$(helm list -n $namespace | grep $release_name | awk '{print $3}')
    PREVIOUS_REVISION=$((CURRENT_REVISION - 1))
    
    if [ $PREVIOUS_REVISION -lt 1 ]; then
        print_error "No previous revision found to rollback to"
        return 1
    fi
    
    echo $PREVIOUS_REVISION
}

# Function to run helm rollback
run_helm_rollback() {
    local release_name=$1
    local namespace=$2
    local revision=$3
    
    print_rollback "Rolling back to revision $revision..."
    
    # Rollback chart
    if helm rollback $release_name $revision \
        --namespace $namespace \
        --timeout 300s \
        --wait 2>&1 | tee -a $ROLLBACK_REPORT; then
        print_info "✅ Helm rollback completed successfully"
        echo "ROLLBACK_STATUS: SUCCESS" >> $ROLLBACK_REPORT
    else
        print_error "❌ Helm rollback failed"
        echo "ROLLBACK_STATUS: FAILED" >> $ROLLBACK_REPORT
        return 1
    fi
}

# Function to validate rollback
validate_rollback() {
    local namespace=$1
    local release_name=$2
    
    print_info "Validating rollback..."
    echo "Rollback Validation:" >> $ROLLBACK_REPORT
    
    # Check if all pods are running
    PENDING_PODS=$(kubectl get pods -n $namespace -l app.kubernetes.io/instance=$release_name --field-selector=status.phase!=Running --no-headers 2>/dev/null | wc -l)
    
    if [ $PENDING_PODS -eq 0 ]; then
        print_info "✅ All pods are running after rollback"
        echo "Pod Status: ALL_RUNNING" >> $ROLLBACK_REPORT
    else
        print_warning "⚠ $PENDING_PODS pods are not running after rollback"
        echo "Pod Status: $PENDING_PODS NOT_RUNNING" >> $ROLLBACK_REPORT
    fi
    
    # Get current revision
    CURRENT_REVISION=$(helm list -n $namespace | grep $release_name | awk '{print $3}')
    echo "Current Revision: $CURRENT_REVISION" >> $ROLLBACK_REPORT
    
    # Show pod status
    print_info "Pod status after rollback:"
    kubectl get pods -n $namespace -l app.kubernetes.io/instance=$release_name >> $ROLLBACK_REPORT 2>&1 || true
}

# Function to show rollback status
show_rollback_status() {
    local namespace=$1
    local release_name=$2
    
    print_info "Showing rollback status..."
    echo "Rollback Status:" >> $ROLLBACK_REPORT
    
    # Get release status
    if helm list -n $namespace | grep -q $release_name; then
        helm status $release_name -n $namespace >> $ROLLBACK_REPORT 2>&1 || true
        echo "---" >> $ROLLBACK_REPORT
        
        # Get events
        print_info "Recent events:"
        kubectl get events -n $namespace --sort-by=.metadata.creationTimestamp --field-selector involvedObject.kind=Pod | tail -20 >> $ROLLBACK_REPORT 2>&1 || true
        
    else
        echo "Release not found" >> $ROLLBACK_REPORT
    fi
}

# Main execution
print_info "Checking if release exists..."
if ! helm list -n $NAMESPACE | grep -q $RELEASE_NAME; then
    print_error "Release $RELEASE_NAME not found in namespace $NAMESPACE"
    echo "ERROR: Release not found" >> $ROLLBACK_REPORT
    exit 1
fi

print_info "Showing release history..."
show_release_history $RELEASE_NAME $NAMESPACE

print_info "Determining rollback revision..."
ROLLBACK_REVISION=$(get_rollback_revision $RELEASE_NAME $NAMESPACE)

if [ $? -ne 0 ]; then
    print_error "Failed to determine rollback revision"
    exit 1
fi

print_info "Rolling back to revision $ROLLBACK_REVISION..."
echo "Rollback Revision: $ROLLBACK_REVISION" >> $ROLLBACK_REPORT

# Perform rollback
run_helm_rollback $RELEASE_NAME $NAMESPACE $ROLLBACK_REVISION

# Show status after rollback
show_rollback_status $NAMESPACE $RELEASE_NAME

# Validate rollback
validate_rollback $NAMESPACE $RELEASE_NAME

# Summary
echo "================================" >> $ROLLBACK_REPORT
echo "Rollback Summary:" >> $ROLLBACK_REPORT
echo "- Release: $RELEASE_NAME" >> $ROLLBACK_REPORT
echo "- Namespace: $NAMESPACE" >> $ROLLBACK_REPORT
echo "- Target: $DEPLOY_TARGET" >> $ROLLBACK_REPORT
echo "- Environment: $ENVIRONMENT" >> $ROLLBACK_REPORT
echo "- Datacenter: $DATACENTER" >> $ROLLBACK_REPORT
echo "- Rollback Revision: $ROLLBACK_REVISION" >> $ROLLBACK_REPORT
echo "- Completed: $(date)" >> $ROLLBACK_REPORT

print_info "✅ Helm rollback process completed!"
echo "📋 Review the rollback report: $ROLLBACK_REPORT"