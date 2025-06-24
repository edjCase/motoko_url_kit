#!/bin/bash

# Public Suffix List to Motoko Module Converter
# Downloads from https://publicsuffix.org/list/public_suffix_list.dat
# Converts to Motoko module format and outputs to DomainSuffixList.mo

set -e

PSL_URL="https://publicsuffix.org/list/public_suffix_list.dat"
TEMP_FILE="public_suffix_list_temp.dat"

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Build output path relative to script location
RELATIVE_OUTPUT_PATH="$SCRIPT_DIR/../src/data/DomainSuffixList.mo"

# Convert to absolute path using multiple fallback methods
get_absolute_path() {
    local path="$1"
    
    # Method 1: Try realpath (most reliable, available on most modern systems)
    if command -v realpath >/dev/null 2>&1; then
        realpath "$path" 2>/dev/null && return 0
    fi
    
    # Method 2: Try readlink -f (common on Linux)
    if command -v readlink >/dev/null 2>&1; then
        readlink -f "$path" 2>/dev/null && return 0
    fi
    
    # Method 3: Manual method using cd and pwd
    local dir_path="$(dirname "$path")"
    local file_name="$(basename "$path")"
    
    if [ -d "$dir_path" ]; then
        echo "$(cd "$dir_path" && pwd)/$file_name"
    else
        # If directory doesn't exist yet, resolve parent directories
        local parent_dir="$(dirname "$dir_path")"
        if [ -d "$parent_dir" ]; then
            echo "$(cd "$parent_dir" && pwd)/$(basename "$dir_path")/$file_name"
        else
            # Create the directory structure to resolve the path
            mkdir -p "$dir_path" 2>/dev/null
            if [ -d "$dir_path" ]; then
                echo "$(cd "$dir_path" && pwd)/$file_name"
            else
                # Final fallback - just expand the path manually
                echo "$(cd "$(dirname "$SCRIPT_DIR")" && pwd)/src/data/$file_name"
            fi
        fi
    fi
}

OUTPUT_FILE="$(get_absolute_path "$RELATIVE_OUTPUT_PATH")"

# Create the output directory if it doesn't exist
OUTPUT_DIR="$(dirname "$OUTPUT_FILE")"
if [ ! -d "$OUTPUT_DIR" ]; then
    echo "Creating output directory: $OUTPUT_DIR"
    mkdir -p "$OUTPUT_DIR"
fi

# Check if we can write to the output directory
if [ ! -w "$OUTPUT_DIR" ]; then
    echo "Error: Cannot write to output directory: $OUTPUT_DIR"
    echo "Please check permissions."
    exit 1
fi

echo "Downloading public suffix list from $PSL_URL..."

# Download the file using curl (fallback to wget if curl not available)
if command -v curl >/dev/null 2>&1; then
    curl -s -o "$TEMP_FILE" "$PSL_URL"
elif command -v wget >/dev/null 2>&1; then
    wget -q -O "$TEMP_FILE" "$PSL_URL"
else
    echo "Error: Neither curl nor wget is available for downloading the file."
    exit 1
fi

# Check if download was successful
if [ ! -f "$TEMP_FILE" ] || [ ! -s "$TEMP_FILE" ]; then
    echo "Error: Failed to download the public suffix list."
    rm -f "$TEMP_FILE"
    exit 1
fi

echo "Converting to Motoko module format..."

# Process the file and create Motoko module:
# 1. Remove comment lines (starting with //)
# 2. Remove empty lines
# 3. Trim whitespace
# 4. Convert to Motoko module format
{
    echo "module {"
    echo "  public let value = ["
    
    # Process domains and add proper indentation
    grep -v '^//' "$TEMP_FILE" | \
    grep -v '^[[:space:]]*$' | \
    sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | \
    sed 's/.*/    "&",/' | \
    sed '$s/,$//'
    
    echo "  ];"
    echo "}"
} > "$OUTPUT_FILE"

# Check if output file was created successfully
if [ ! -f "$OUTPUT_FILE" ]; then
    echo "Error: Failed to create output file: $OUTPUT_FILE"
    rm -f "$TEMP_FILE"
    exit 1
fi

# Clean up temporary file
rm -f "$TEMP_FILE"

echo "Conversion complete! Motoko module saved to: $OUTPUT_FILE"

# Display some statistics
TOTAL_DOMAINS=$(grep -c '    "' "$OUTPUT_FILE")
echo "Total domains processed: $TOTAL_DOMAINS"