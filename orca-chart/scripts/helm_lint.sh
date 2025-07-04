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

# Initialize lint report
LINT_REPORT="lint-report.txt"
echo "Helm Lint Report - $(date)" > $LINT_REPORT
echo "================================" >> $LINT_REPORT

# Initialize lint status
LINT_PASSED=true

print_info "Starting Helm lint process..."

# Values file to use
VALUES_FILE="environments/${ENVIRONMENT}-values.yaml"

# Function to lint a specific chart
lint_chart() {
    local chart_name=$1
    local chart_path=$2
    
    print_info "Linting chart: $chart_name"
    echo "Linting $chart_name:" >> $LINT_REPORT
    
    # Create temporary values file with component enabled
    TEMP_VALUES=$(mktemp)
    cp $VALUES_FILE $TEMP_VALUES
    
    # Enable the specific component if not umbrella
    if [ "$chart_name" != "umbrella" ]; then
        echo "components:" >> $TEMP_VALUES
        echo "  $chart_name:" >> $TEMP_VALUES
        echo "    enabled: true" >> $TEMP_VALUES
    fi
    
    # Run helm lint
    if helm lint $chart_path --values $TEMP_VALUES --strict 2>&1 | tee -a $LINT_REPORT; then
        print_info "✓ Lint passed for $chart_name"
        echo "RESULT: PASSED" >> $LINT_REPORT
    else
        print_error "✗ Lint failed for $chart_name"
        echo "RESULT: FAILED" >> $LINT_REPORT
        LINT_PASSED=false
    fi
    
    # Clean up
    rm -f $TEMP_VALUES
    echo "---" >> $LINT_REPORT
}

# Function to lint using template rendering
lint_template() {
    local chart_name=$1
    local chart_path=$2
    
    print_info "Template validation for: $chart_name"
    echo "Template validation for $chart_name:" >> $LINT_REPORT
    
    # Create temporary values file
    TEMP_VALUES=$(mktemp)
    cp $VALUES_FILE $TEMP_VALUES
    
    # Enable the specific component if not umbrella
    if [ "$chart_name" != "umbrella" ]; then
        echo "components:" >> $TEMP_VALUES
        echo "  $chart_name:" >> $TEMP_VALUES
        echo "    enabled: true" >> $TEMP_VALUES
    fi
    
    # Run helm template to validate
    if helm template test-release $chart_path --values $TEMP_VALUES --dry-run 2>&1 | tee -a $LINT_REPORT; then
        print_info "✓ Template validation passed for $chart_name"
        echo "TEMPLATE_RESULT: PASSED" >> $LINT_REPORT
    else
        print_error "✗ Template validation failed for $chart_name"
        echo "TEMPLATE_RESULT: FAILED" >> $LINT_REPORT
        LINT_PASSED=false
    fi
    
    # Clean up
    rm -f $TEMP_VALUES
    echo "---" >> $LINT_REPORT
}

# Update Helm dependencies
print_info "Updating Helm dependencies..."
if helm dependency update . 2>&1 | tee -a $LINT_REPORT; then
    print_info "✓ Helm dependencies updated"
    echo "DEPENDENCIES: UPDATED" >> $LINT_REPORT
else
    print_error "✗ Failed to update Helm dependencies"
    echo "DEPENDENCIES: FAILED" >> $LINT_REPORT
    LINT_PASSED=false
fi

# Lint based on DEPLOY_TARGET
case $DEPLOY_TARGET in
    "umbrella")
        print_info "Linting umbrella chart..."
        lint_chart "umbrella" "."
        lint_template "umbrella" "."
        ;;
    "airflow")
        print_info "Linting Airflow chart..."
        if [ -d "charts/airflow" ]; then
            lint_chart "airflow" "charts/airflow"
            lint_template "airflow" "charts/airflow"
        else
            print_info "Using umbrella chart with Airflow component..."
            lint_chart "airflow" "."
            lint_template "airflow" "."
        fi
        ;;
    "spark")
        print_info "Linting Spark chart..."
        if [ -d "charts/spark" ]; then
            lint_chart "spark" "charts/spark"
            lint_template "spark" "charts/spark"
        else
            print_info "Using umbrella chart with Spark component..."
            lint_chart "spark" "."
            lint_template "spark" "."
        fi
        ;;
    "postgres")
        print_info "Linting PostgreSQL chart..."
        if [ -d "charts/postgres" ]; then
            lint_chart "postgres" "charts/postgres"
            lint_template "postgres" "charts/postgres"
        else
            print_info "Using umbrella chart with PostgreSQL component..."
            lint_chart "postgres" "."
            lint_template "postgres" "."
        fi
        ;;
    *)
        print_error "Unknown DEPLOY_TARGET: $DEPLOY_TARGET"
        echo "ERROR: Unknown DEPLOY_TARGET: $DEPLOY_TARGET" >> $LINT_REPORT
        LINT_PASSED=false
        ;;
esac

# Additional validation checks
print_info "Performing additional validation checks..."

# Check for required secrets
print_info "Checking for required secrets..."
if grep -q "existingSecret" $VALUES_FILE; then
    print_info "✓ Secrets configuration found"
    echo "SECRETS: CONFIGURED" >> $LINT_REPORT
else
    print_warning "⚠ No secrets configuration found"
    echo "SECRETS: NOT CONFIGURED" >> $LINT_REPORT
fi

# Check for resource limits
print_info "Checking for resource limits..."
if grep -q "resources:" $VALUES_FILE && grep -q "limits:" $VALUES_FILE; then
    print_info "✓ Resource limits configured"
    echo "RESOURCES: CONFIGURED" >> $LINT_REPORT
else
    print_warning "⚠ Resource limits not found"
    echo "RESOURCES: NOT CONFIGURED" >> $LINT_REPORT
fi

# Check for persistent volume claims
print_info "Checking for persistent volume claims..."
if grep -q "persistence:" $VALUES_FILE && grep -q "enabled: true" $VALUES_FILE; then
    print_info "✓ Persistence configured"
    echo "PERSISTENCE: CONFIGURED" >> $LINT_REPORT
else
    print_warning "⚠ Persistence not configured"
    echo "PERSISTENCE: NOT CONFIGURED" >> $LINT_REPORT
fi

# Validate YAML syntax
print_info "Validating YAML syntax..."
if python3 -c "import yaml; yaml.safe_load(open('$VALUES_FILE'))" 2>&1 | tee -a $LINT_REPORT; then
    print_info "✓ YAML syntax is valid"
    echo "YAML_SYNTAX: VALID" >> $LINT_REPORT
else
    print_error "✗ YAML syntax is invalid"
    echo "YAML_SYNTAX: INVALID" >> $LINT_REPORT
    LINT_PASSED=false
fi

# Final lint result
echo "================================" >> $LINT_REPORT
if [ "$LINT_PASSED" = true ]; then
    print_info "✅ All lint checks passed!"
    echo "LINT_RESULT: PASSED" >> $LINT_REPORT
    exit 0
else
    print_error "❌ Lint checks failed!"
    echo "LINT_RESULT: FAILED" >> $LINT_REPORT
    exit 1
fi