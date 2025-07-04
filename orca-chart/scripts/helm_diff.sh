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

print_diff() {
    echo -e "${BLUE}[DIFF]${NC} $1"
}

# Initialize diff report
DIFF_REPORT="diff-report.txt"
echo "Helm Diff Report - $(date)" > $DIFF_REPORT
echo "================================" >> $DIFF_REPORT

print_info "Starting Helm diff process..."

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

echo "Release: $RELEASE_NAME" >> $DIFF_REPORT
echo "Namespace: $NAMESPACE" >> $DIFF_REPORT
echo "Deploy Target: $DEPLOY_TARGET" >> $DIFF_REPORT
echo "Environment: $ENVIRONMENT" >> $DIFF_REPORT
echo "Datacenter: $DATACENTER" >> $DIFF_REPORT
echo "---" >> $DIFF_REPORT

# Function to run helm diff
run_helm_diff() {
    local chart_path=$1
    local release_name=$2
    local namespace=$3
    
    print_info "Running Helm diff for $release_name in namespace $namespace..."
    
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
    
    # Check if release exists
    if helm list -n $namespace | grep -q $release_name; then
        print_info "Release $release_name exists. Generating diff..."
        echo "Release Status: EXISTS" >> $DIFF_REPORT
        
        # Run helm diff
        if helm diff upgrade $release_name $chart_path \
            --namespace $namespace \
            --values $TEMP_VALUES \
            --detailed-exitcode \
            --no-hooks \
            --suppress-secrets 2>&1 | tee -a $DIFF_REPORT; then
            print_info "✓ No changes detected"
            echo "DIFF_STATUS: NO_CHANGES" >> $DIFF_REPORT
        else
            DIFF_EXIT_CODE=$?
            if [ $DIFF_EXIT_CODE -eq 2 ]; then
                print_diff "📋 Changes detected - see diff above"
                echo "DIFF_STATUS: CHANGES_DETECTED" >> $DIFF_REPORT
            else
                print_error "✗ Helm diff failed with exit code $DIFF_EXIT_CODE"
                echo "DIFF_STATUS: FAILED" >> $DIFF_REPORT
                rm -f $TEMP_VALUES
                return 1
            fi
        fi
    else
        print_info "Release $release_name does not exist. This will be a new installation."
        echo "Release Status: NEW_INSTALLATION" >> $DIFF_REPORT
        
        # Show what will be installed
        print_info "Showing what will be installed..."
        echo "Resources to be created:" >> $DIFF_REPORT
        helm template $release_name $chart_path \
            --namespace $namespace \
            --values $TEMP_VALUES \
            --debug \
            --dry-run 2>&1 | tee -a $DIFF_REPORT
        
        echo "DIFF_STATUS: NEW_INSTALLATION" >> $DIFF_REPORT
    fi
    
    # Clean up
    rm -f $TEMP_VALUES
}

# Function to show current resources
show_current_resources() {
    local namespace=$1
    local release_name=$2
    
    print_info "Showing current resources for release $release_name..."
    echo "Current Resources:" >> $DIFF_REPORT
    
    # Get current release info
    if helm list -n $namespace | grep -q $release_name; then
        helm get values $release_name -n $namespace >> $DIFF_REPORT 2>&1 || true
        echo "---" >> $DIFF_REPORT
        helm get manifest $release_name -n $namespace >> $DIFF_REPORT 2>&1 || true
    else
        echo "No existing release found" >> $DIFF_REPORT
    fi
}

# Function to validate resources
validate_resources() {
    local namespace=$1
    
    print_info "Validating resources in namespace $namespace..."
    echo "Resource Validation:" >> $DIFF_REPORT
    
    # Check if namespace exists
    if kubectl get namespace $namespace >/dev/null 2>&1; then
        print_info "✓ Namespace $namespace exists"
        echo "Namespace: EXISTS" >> $DIFF_REPORT
    else
        print_warning "⚠ Namespace $namespace does not exist (will be created)"
        echo "Namespace: WILL_BE_CREATED" >> $DIFF_REPORT
    fi
    
    # Check storage classes
    if kubectl get storageclass >/dev/null 2>&1; then
        print_info "✓ Storage classes available"
        echo "Storage Classes:" >> $DIFF_REPORT
        kubectl get storageclass -o name >> $DIFF_REPORT
    else
        print_warning "⚠ No storage classes found"
        echo "Storage Classes: NONE" >> $DIFF_REPORT
    fi
    
    # Check for existing PVCs
    if kubectl get pvc -n $namespace >/dev/null 2>&1; then
        print_info "Current PVCs in namespace:"
        echo "Existing PVCs:" >> $DIFF_REPORT
        kubectl get pvc -n $namespace >> $DIFF_REPORT
    else
        print_info "No existing PVCs found"
        echo "Existing PVCs: NONE" >> $DIFF_REPORT
    fi
}

# Ensure namespace exists or create it
ensure_namespace() {
    local namespace=$1
    
    if ! kubectl get namespace $namespace >/dev/null 2>&1; then
        print_info "Creating namespace $namespace..."
        kubectl create namespace $namespace
        echo "Namespace $namespace created" >> $DIFF_REPORT
    fi
}

# Main execution
case $DEPLOY_TARGET in
    "umbrella")
        print_info "Running diff for umbrella chart..."
        show_current_resources $NAMESPACE $RELEASE_NAME
        ensure_namespace $NAMESPACE
        validate_resources $NAMESPACE
        run_helm_diff "." $RELEASE_NAME $NAMESPACE
        ;;
    "airflow"|"spark"|"postgres")
        print_info "Running diff for $DEPLOY_TARGET chart..."
        show_current_resources $NAMESPACE $RELEASE_NAME
        ensure_namespace $NAMESPACE
        validate_resources $NAMESPACE
        
        if [ -d "charts/$DEPLOY_TARGET" ]; then
            run_helm_diff "charts/$DEPLOY_TARGET" $RELEASE_NAME $NAMESPACE
        else
            print_info "Using umbrella chart with $DEPLOY_TARGET component..."
            run_helm_diff "." $RELEASE_NAME $NAMESPACE
        fi
        ;;
    *)
        print_error "Unknown DEPLOY_TARGET: $DEPLOY_TARGET"
        echo "ERROR: Unknown DEPLOY_TARGET: $DEPLOY_TARGET" >> $DIFF_REPORT
        exit 1
        ;;
esac

# Summary
echo "================================" >> $DIFF_REPORT
echo "Diff Summary:" >> $DIFF_REPORT
echo "- Release: $RELEASE_NAME" >> $DIFF_REPORT
echo "- Namespace: $NAMESPACE" >> $DIFF_REPORT
echo "- Target: $DEPLOY_TARGET" >> $DIFF_REPORT
echo "- Environment: $ENVIRONMENT" >> $DIFF_REPORT
echo "- Datacenter: $DATACENTER" >> $DIFF_REPORT
echo "- Completed: $(date)" >> $DIFF_REPORT

print_info "✅ Helm diff completed successfully!"
echo "📋 Review the diff report: $DIFF_REPORT"