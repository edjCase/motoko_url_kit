#!/bin/bash

# Public Suffix List to Motoko Compact Format Converter
# Downloads from https://publicsuffix.org/list/public_suffix_list.dat
# Converts to compact format and outputs to DomainSuffixData.mo

set -e

PSL_URL="https://publicsuffix.org/list/public_suffix_list.dat"
TEMP_FILE="public_suffix_list_temp.dat"
PROCESSED_FILE="processed_suffixes.txt"

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Build output path relative to script location
RELATIVE_OUTPUT_PATH="$SCRIPT_DIR/../src/data/DomainSuffixData.mo"

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

echo "Processing public suffix list..."

# Process the file: remove comments and empty lines only
grep -v '^//' "$TEMP_FILE" | \
grep -v '^[[:space:]]*$' > "$PROCESSED_FILE"

echo "Converting to compact format..."

# Use Python for building compact format
python3 -c "
import sys
from collections import defaultdict

# Read all suffixes
suffixes = []
with open('processed_suffixes.txt', 'r') as f:
    for line in f:
        line = line.strip()
        if line:
            suffixes.append(line)

# Build tree structure with terminal marking
tree = {}
terminals = set()
wildcards = {}

for suffix in suffixes:
    parts = suffix.split('.')
    if (parts[0] == '*'):
        parts = parts[1:]  # Remove wildcard part
        wildcards['.'.join(parts)] = []
    elif (parts[0].startswith('!')):
        key = '.'.join(parts[1:])
        # raise ValueError(f'Exception without wildcard base: {key} for wildcards {wildcards.keys()} adding {parts[0][1:]}')
        wildcards['.'.join(parts[1:])].append(parts[0][1:])
        continue  # Ignore exceptions for tree building
    else:
        terminals.add(suffix)
    
    parts.reverse()  # Reverse to start from TLD
    
    current = tree
    path = []
    for part in parts:
        path.append(part)
        if part not in current:
            current[part] = {}
        current = current[part]

def serialize_node(node, path=''):
    if not node:
        return ''
    
    sorted_keys = sorted(node.keys())
    segments = []
    
    for key in sorted_keys:
        current_path = f'{key}.{path}' if path else key
        children = node[key]
        
        is_terminal = current_path in terminals
        segment = key
        if children:
            child_str = serialize_node(children, current_path)

            if is_terminal:
                segment += '!'
            segment += f'>{child_str}'

            segments.append(segment)
        else:
            # Leaf node
            if current_path in wildcards:
                segment += ('^' if is_terminal else '*') + ','.join(wildcards[current_path])
            segments.append(segment)
    
    if not path:  # Root level
        return '|'.join(segments)
    else:
        # Process segments to add parentheses only around individual items with children
        processed_segments = []
        for segment in segments:
            if '>' in segment:
                processed_segments.append(f'({segment})')
            else:
                processed_segments.append(segment)
        
        return ','.join(processed_segments)

compact_format = serialize_node(tree)

motoko_content = f'''module {{
  public let value = \"{compact_format}\";
}}'''

with open('src/data/DomainSuffixData.mo', 'w') as f:
    f.write(motoko_content)
"

# Check if output file was created successfully
if [ ! -f "$OUTPUT_FILE" ]; then
    echo "Error: Failed to create output file: $OUTPUT_FILE"
    rm -f "$TEMP_FILE" "$PROCESSED_FILE"
    exit 1
fi

# Clean up temporary files
rm -f "$TEMP_FILE" "$PROCESSED_FILE"

echo "Conversion complete! Motoko compact format saved to: $OUTPUT_FILE"