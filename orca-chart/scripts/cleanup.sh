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

print_cleanup() {
    echo -e "${BLUE}[CLEANUP]${NC} $1"
}

# Initialize cleanup report
CLEANUP_REPORT="cleanup-report.txt"
echo "Cleanup Report - $(date)" > $CLEANUP_REPORT
echo "================================" >> $CLEANUP_REPORT

print_info "Starting cleanup process..."

# Function to cleanup temporary files
cleanup_temp_files() {
    print_cleanup "Cleaning up temporary files..."
    
    # Remove temporary values files
    find /tmp -name "tmp.*" -type f -mtime +1 -exec rm -f {} \; 2>/dev/null || true
    
    # Remove old reports (keep last 10)
    for report_type in validation lint diff deployment rollback; do
        if ls ${report_type}-report-*.txt 1> /dev/null 2>&1; then
            ls -t ${report_type}-report-*.txt | tail -n +11 | xargs rm -f 2>/dev/null || true
        fi
    done
    
    # Remove old charts directory if exists
    if [ -d "charts" ]; then
        find charts -name "*.tgz" -type f -mtime +7 -exec rm -f {} \; 2>/dev/null || true
    fi
    
    echo "Temporary files cleaned" >> $CLEANUP_REPORT
}

# Function to cleanup Docker images (if running locally)
cleanup_docker_images() {
    print_cleanup "Cleaning up Docker images..."
    
    if command -v docker &> /dev/null; then
        # Remove dangling images
        docker image prune -f 2>/dev/null || true
        
        # Remove unused images older than 7 days
        docker image prune -a --filter "until=168h" -f 2>/dev/null || true
        
        echo "Docker images cleaned" >> $CLEANUP_REPORT
    else
        echo "Docker not available, skipping image cleanup" >> $CLEANUP_REPORT
    fi
}

# Function to cleanup Helm cache
cleanup_helm_cache() {
    print_cleanup "Cleaning up Helm cache..."
    
    # Clear Helm repository cache
    helm repo list | grep -v NAME | awk '{print $1}' | xargs -I {} helm repo remove {} 2>/dev/null || true
    
    # Re-add required repositories
    helm repo add bitnami https://charts.bitnami.com/bitnami 2>/dev/null || true
    helm repo add apache-airflow https://airflow.apache.org 2>/dev/null || true
    helm repo update 2>/dev/null || true
    
    echo "Helm cache cleaned" >> $CLEANUP_REPORT
}

# Function to cleanup failed deployments
cleanup_failed_deployments() {
    print_cleanup "Cleaning up failed deployments..."
    
    # Get namespace
    NAMESPACE="orca-${ENVIRONMENT}"
    
    if kubectl get namespace $NAMESPACE >/dev/null 2>&1; then
        # Get failed pods
        FAILED_PODS=$(kubectl get pods -n $NAMESPACE --field-selector=status.phase=Failed --no-headers 2>/dev/null | wc -l)
        
        if [ $FAILED_PODS -gt 0 ]; then
            print_info "Found $FAILED_PODS failed pods"
            kubectl delete pods -n $NAMESPACE --field-selector=status.phase=Failed 2>/dev/null || true
            echo "Failed pods deleted: $FAILED_PODS" >> $CLEANUP_REPORT
        else
            echo "No failed pods found" >> $CLEANUP_REPORT
        fi
        
        # Get completed jobs older than 24 hours
        COMPLETED_JOBS=$(kubectl get jobs -n $NAMESPACE --field-selector=status.successful=1 --no-headers 2>/dev/null | wc -l)
        
        if [ $COMPLETED_JOBS -gt 0 ]; then
            print_info "Found $COMPLETED_JOBS completed jobs"
            # Delete completed jobs older than 24 hours
            kubectl get jobs -n $NAMESPACE --field-selector=status.successful=1 -o jsonpath='{range .items[*]}{.metadata.name}{" "}{.status.completionTime}{"\n"}{end}' | \
            while read job_name completion_time; do
                if [ -n "$completion_time" ]; then
                    # Convert completion time to epoch
                    completion_epoch=$(date -d "$completion_time" +%s 2>/dev/null || echo 0)
                    current_epoch=$(date +%s)
                    age_hours=$(( (current_epoch - completion_epoch) / 3600 ))
                    
                    if [ $age_hours -gt 24 ]; then
                        kubectl delete job $job_name -n $NAMESPACE 2>/dev/null || true
                    fi
                fi
            done
            echo "Old completed jobs cleaned" >> $CLEANUP_REPORT
        else
            echo "No completed jobs found" >> $CLEANUP_REPORT
        fi
        
        # Clean up unused configmaps and secrets (be careful with this)
        # This is commented out for safety - uncomment if needed
        # kubectl get configmaps -n $NAMESPACE --no-headers | grep -E "(helm|test)" | awk '{print $1}' | xargs -I {} kubectl delete configmap {} -n $NAMESPACE 2>/dev/null || true
        
    else
        echo "Namespace $NAMESPACE not found" >> $CLEANUP_REPORT
    fi
}

# Function to cleanup old PVCs (if specified)
cleanup_old_pvcs() {
    print_cleanup "Checking for old PVCs..."
    
    NAMESPACE="orca-${ENVIRONMENT}"
    
    if kubectl get namespace $NAMESPACE >/dev/null 2>&1; then
        # List PVCs but don't delete them automatically for safety
        PVC_COUNT=$(kubectl get pvc -n $NAMESPACE --no-headers 2>/dev/null | wc -l)
        
        if [ $PVC_COUNT -gt 0 ]; then
            print_info "Found $PVC_COUNT PVCs in namespace $NAMESPACE"
            kubectl get pvc -n $NAMESPACE >> $CLEANUP_REPORT 2>&1 || true
            echo "PVCs listed (not deleted for safety)" >> $CLEANUP_REPORT
        else
            echo "No PVCs found" >> $CLEANUP_REPORT
        fi
    else
        echo "Namespace $NAMESPACE not found" >> $CLEANUP_REPORT
    fi
}

# Function to send notifications
send_notifications() {
    print_cleanup "Sending notifications..."
    
    # Send notification to Slack/Teams/Email if configured
    if [ -n "$SLACK_WEBHOOK" ]; then
        SLACK_MESSAGE="Orca Chart Cleanup completed for ${ENVIRONMENT} environment"
        curl -X POST -H 'Content-type: application/json' \
            --data "{\"text\":\"$SLACK_MESSAGE\"}" \
            $SLACK_WEBHOOK 2>/dev/null || true
        echo "Slack notification sent" >> $CLEANUP_REPORT
    fi
    
    # Send email notification if configured
    if [ -n "$EMAIL_RECIPIENTS" ]; then
        SUBJECT="Orca Chart Cleanup - ${ENVIRONMENT}"
        BODY="Cleanup completed for Orca Chart deployment in ${ENVIRONMENT} environment. Check the pipeline for details."
        
        # Use mail command if available
        if command -v mail &> /dev/null; then
            echo "$BODY" | mail -s "$SUBJECT" "$EMAIL_RECIPIENTS" 2>/dev/null || true
            echo "Email notification sent" >> $CLEANUP_REPORT
        fi
    fi
}

# Function to generate cleanup summary
generate_cleanup_summary() {
    print_cleanup "Generating cleanup summary..."
    
    echo "================================" >> $CLEANUP_REPORT
    echo "Cleanup Summary:" >> $CLEANUP_REPORT
    echo "- Environment: $ENVIRONMENT" >> $CLEANUP_REPORT
    echo "- Datacenter: $DATACENTER" >> $CLEANUP_REPORT
    echo "- Pipeline ID: $CI_PIPELINE_ID" >> $CLEANUP_REPORT
    echo "- Job ID: $CI_JOB_ID" >> $CLEANUP_REPORT
    echo "- Completed: $(date)" >> $CLEANUP_REPORT
    echo "- Duration: $((SECONDS / 60)) minutes" >> $CLEANUP_REPORT
    
    # Disk usage
    echo "- Disk usage: $(df -h . | tail -1 | awk '{print $3 "/" $2 " (" $5 ")"}')" >> $CLEANUP_REPORT
    
    # Memory usage
    echo "- Memory usage: $(free -h | grep Mem | awk '{print $3 "/" $2}')" >> $CLEANUP_REPORT
}

# Main execution
print_info "Environment: $ENVIRONMENT"
print_info "Datacenter: $DATACENTER"
print_info "Pipeline ID: $CI_PIPELINE_ID"

echo "Environment: $ENVIRONMENT" >> $CLEANUP_REPORT
echo "Datacenter: $DATACENTER" >> $CLEANUP_REPORT
echo "Pipeline ID: $CI_PIPELINE_ID" >> $CLEANUP_REPORT
echo "Started: $(date)" >> $CLEANUP_REPORT
echo "---" >> $CLEANUP_REPORT

# Start timer
SECONDS=0

# Perform cleanup tasks
cleanup_temp_files
cleanup_docker_images
cleanup_helm_cache
cleanup_failed_deployments
cleanup_old_pvcs

# Send notifications
send_notifications

# Generate summary
generate_cleanup_summary

print_info "✅ Cleanup process completed!"
echo "📋 Review the cleanup report: $CLEANUP_REPORT"

# Archive reports if in production
if [ "$ENVIRONMENT" = "prod" ]; then
    print_info "Archiving reports for production environment..."
    ARCHIVE_DIR="archives/$(date +%Y%m%d)"
    mkdir -p $ARCHIVE_DIR
    cp *-report.txt $ARCHIVE_DIR/ 2>/dev/null || true
    echo "Reports archived to $ARCHIVE_DIR" >> $CLEANUP_REPORT
fi