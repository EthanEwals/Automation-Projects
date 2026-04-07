#!/bin/bash

# Input file
INPUT_FILE="systems.csv"
OUTPUT_FILE="patch_report_bash.csv"

# Colors for console output
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to validate date format
validate_date() {
    local date_str=$1
    if [[ $date_str =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]] && date -d "$date_str" >/dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

# Function to validate criticality
validate_criticality() {
    local crit=$1
    case $crit in
        "Low"|"Medium"|"High"|"Critical") return 0 ;;
        *) return 1 ;;
    esac
}

# Function to calculate days since patch
calculate_days_since_patch() {
    local patch_date=$1
    local current_epoch=$(date +%s)
    local patch_epoch=$(date -d "$patch_date" +%s 2>/dev/null)
    
    if [ -z "$patch_epoch" ]; then
        echo "Invalid"
        return
    fi
    
    local diff_seconds=$((current_epoch - patch_epoch))
    local diff_days=$((diff_seconds / 86400))
    echo $diff_days
}

# Function to get compliance status
get_compliance_status() {
    local days=$1
    if [ "$days" = "Invalid" ]; then
        echo "❌ Invalid Date"
    elif [ $days -le 30 ]; then
        echo "✅ Compliant"
    elif [ $days -le 59 ]; then
        echo "⚠️ Warning"
    else
        echo "❌ Outdated"
    fi
}

# Function to get criticality weight
get_criticality_weight() {
    local criticality=$1
    case $criticality in
        "Low") echo 1 ;;
        "Medium") echo 2 ;;
        "High") echo 3 ;;
        "Critical") echo 4 ;;
        *) echo 0 ;;
    esac
}

# Function to calculate risk score
calculate_risk_score() {
    local days=$1
    local criticality=$2
    
    if [ "$days" = "Invalid" ]; then
        echo "10.0"  # High risk for invalid dates
        return
    fi
    
    local weight=$(get_criticality_weight "$criticality")
    local risk=$(echo "scale=2; ($days / 10) + $weight" | bc)
    echo "$risk"
}

# Function to get color for status
get_status_color() {
    local status=$1
    case $status in
        *"Compliant"*) echo -e "${GREEN}" ;;
        *"Warning"*) echo -e "${YELLOW}" ;;
        *"Outdated"*|*"Invalid"*) echo -e "${RED}" ;;
        *) echo -e "${NC}" ;;
    esac
}

# Check if input file exists
if [ ! -f "$INPUT_FILE" ]; then
    echo -e "${RED}Error: $INPUT_FILE not found!${NC}"
    exit 1
fi

# Initialize counters
total_systems=0
compliant_count=0
warning_count=0
outdated_count=0
total_risk=0

# Create output file with header
echo "Hostname,OS,LastPatchDate,Criticality,DaysSincePatch,ComplianceStatus,RiskScore" > "$OUTPUT_FILE"

# Process CSV file
echo -e "${BLUE}=== Patch Compliance Report ===${NC}"
echo -e "${BLUE}Generated on: $(date)${NC}\n"

# Process each line in CSV
while IFS=',' read -r hostname os last_patch criticality || [ -n "$hostname" ]; do
    # Skip empty lines and header
    if [ -z "$hostname" ] || [ "$hostname" = "Hostname" ] || [[ "$hostname" =~ ^[[:space:]]*$ ]]; then
        continue
    fi
    
    # Validate criticality
    if ! validate_criticality "$criticality"; then
        echo -e "${YELLOW}Warning: Skipping invalid criticality for $hostname: $criticality${NC}"
        continue
    fi
    
    # Validate date
    if ! validate_date "$last_patch"; then
        echo -e "${YELLOW}Warning: Skipping invalid date for $hostname: $last_patch${NC}"
        continue
    fi
    
    # Calculate days since patch
    days_since_patch=$(calculate_days_since_patch "$last_patch")
    
    # Get compliance status
    compliance_status=$(get_compliance_status "$days_since_patch")
    
    # Calculate risk score
    risk_score=$(calculate_risk_score "$days_since_patch" "$criticality")
    
    # Update counters
    total_systems=$((total_systems + 1))
    case $compliance_status in
        *"Compliant"*) compliant_count=$((compliant_count + 1)) ;;
        *"Warning"*) warning_count=$((warning_count + 1)) ;;
        *"Outdated"*) outdated_count=$((outdated_count + 1)) ;;
    esac
    
    # Add to total risk for average calculation
    total_risk=$(echo "scale=2; $total_risk + $risk_score" | bc)
    
    # Write to output file
    echo "$hostname,$os,$last_patch,$criticality,$days_since_patch,$compliance_status,$risk_score" >> "$OUTPUT_FILE"
    
done < "$INPUT_FILE"

# Generate sorted and color-coded console output
echo -e "${BLUE}=== Systems Sorted by Risk Score (Highest First) ===${NC}"
echo ""

# Display sorted results with colors
sort -t',' -k7,7nr "$OUTPUT_FILE" | tail -n +2 | while IFS=',' read -r hostname os last_patch criticality days status risk; do
    color=$(get_status_color "$status")
    printf "%-15s %-10s %-12s %-10s %-4s $color%-15s${NC} %-6s\n" \
        "$hostname" "$os" "$last_patch" "$criticality" "$days" "$status" "$risk"
done

# Calculate average risk
if [ $total_systems -gt 0 ]; then
    average_risk=$(echo "scale=2; $total_risk / $total_systems" | bc)
else
    average_risk=0
fi

# Display summary
echo ""
echo -e "${BLUE}=== Compliance Summary ===${NC}"
echo -e "Total Systems Checked: $total_systems"
echo -e "${GREEN}✅ Compliant: $compliant_count${NC}"
echo -e "${YELLOW}⚠️ Warning: $warning_count${NC}"
echo -e "${RED}❌ Outdated: $outdated_count${NC}"
echo -e "Average Risk Score: $average_risk"

echo ""
echo -e "${GREEN}Report exported to: $OUTPUT_FILE${NC}"