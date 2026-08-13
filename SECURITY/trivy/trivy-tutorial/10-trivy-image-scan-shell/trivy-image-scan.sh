#!/bin/bash
set -euo pipefail

INPUT_FILE="scan-image.txt"

# Check prerequisites
command -v trivy >/dev/null || { echo "❌ Trivy not installed"; exit 1; }
command -v wget  >/dev/null || { echo "❌ wget not installed"; exit 1; }

# Check input file
[[ -f "$INPUT_FILE" ]] || { echo "❌ $INPUT_FILE not found"; exit 1; }

# Download template once
if [[ ! -f html.tpl ]]; then
    wget -q https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/html.tpl -O html.tpl
fi

while IFS= read -r image || [[ -n "$image" ]]; do
    [[ -z "$image" ]] && continue

    echo "🔍 Scanning: $image"
    
    mkdir -p reports
    
    sanitized_image_name=$(echo "$image" | sed 's/[:/]/_/g')
    output_file="reports/${sanitized_image_name}.html"

    trivy image \
        --severity HIGH,CRITICAL \
        --format template \
        --template @html.tpl \
        -o "$output_file" \
        "$image"

    echo "✅ Report generated: $output_file"
    echo "--------------------------------------"

done < "$INPUT_FILE"

echo "All scans completed successfully"