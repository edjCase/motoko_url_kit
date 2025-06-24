#!/bin/bash

# Public Suffix List to Motoko Tree Module Converter
# Downloads from https://publicsuffix.org/list/public_suffix_list.dat
# Converts to Motoko tree module format and outputs to DomainSuffixList.mo

set -e

PSL_URL="https://publicsuffix.org/list/public_suffix_list.dat"
TEMP_FILE="public_suffix_list_temp.dat"
PROCESSED_FILE="processed_suffixes.txt"

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

echo "Processing public suffix list..."

# Process the file: remove comments, empty lines, wildcards, and exceptions
grep -v '^//' "$TEMP_FILE" | \
grep -v '^[[:space:]]*$' | \
sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | \
grep -v '^!' | \
sed 's/^\*\.//' > "$PROCESSED_FILE"

echo "Converting to Motoko tree module format..."

# Use Python for efficient tree building (much faster than bash)
python3 << 'EOF'
import sys
from collections import defaultdict

# Read all suffixes
suffixes = set()
with open('processed_suffixes.txt', 'r') as f:
    for line in f:
        line = line.strip()
        if line:
            suffixes.add(line)

# Build tree structure efficiently
tree = defaultdict(lambda: {'is_terminal': False, 'children': defaultdict(lambda: {'is_terminal': False, 'children': {}})})

# Process each suffix
for suffix in suffixes:
    parts = suffix.split('.')
    parts.reverse()  # Reverse to start from TLD
    
    current = tree
    path = []
    
    for i, part in enumerate(parts):
        path.append(part)
        if part not in current:
            current[part] = {'is_terminal': False, 'children': defaultdict(lambda: {'is_terminal': False, 'children': {}})}
        
        # Check if this partial path is a terminal suffix
        current_suffix = '.'.join(reversed(path))
        if current_suffix in suffixes:
            current[part]['is_terminal'] = True
            
        current = current[part]['children']

def generate_motoko_tree(node_dict, indent_level=2):
    """Generate Motoko code for the tree structure"""
    if not node_dict:
        return ""
    
    indent = "  " * indent_level
    entries = []
    
    # Sort keys for consistent output
    for key in sorted(node_dict.keys()):
        node = node_dict[key]
        is_terminal = str(node['is_terminal']).lower()
        
        # Generate children recursively
        children_code = generate_motoko_tree(node['children'], indent_level + 1)
        
        entry = f"""{indent}{{
{indent}  id = "{key}";
{indent}  isTerminal = {is_terminal};
{indent}  children = ["""
        
        if children_code:
            entry += f"\n{children_code}\n{indent}  ];\n{indent}}}"
        else:
            entry += f"];\n{indent}}}"
            
        entries.append(entry)
    
    return ",\n".join(entries)

# Generate the complete Motoko module
motoko_content = f"""module {{
  public type SuffixEntry = {{
    id : Text;
    isTerminal : Bool; // Can end here
    children : [SuffixEntry]; // Possible sub-suffixes
  }};

  public let value = [
{generate_motoko_tree(tree)}
  ];
}}"""

# Write to output file
with open(sys.argv[1] if len(sys.argv) > 1 else 'DomainSuffixList.mo', 'w') as f:
    f.write(motoko_content)

print(f"Total suffixes processed: {len(suffixes)}")
print(f"Top-level domains: {len(tree)}")
EOF

# Run the Python script with the output file path
python3 -c "
import sys
from collections import defaultdict

# Read all suffixes
suffixes = set()
with open('processed_suffixes.txt', 'r') as f:
    for line in f:
        line = line.strip()
        if line:
            suffixes.add(line)

# Build tree structure efficiently
tree = defaultdict(lambda: {'is_terminal': False, 'children': defaultdict(lambda: {'is_terminal': False, 'children': {}})})

# Process each suffix
for suffix in suffixes:
    parts = suffix.split('.')
    parts.reverse()  # Reverse to start from TLD
    
    current = tree
    path = []
    
    for i, part in enumerate(parts):
        path.append(part)
        if part not in current:
            current[part] = {'is_terminal': False, 'children': defaultdict(lambda: {'is_terminal': False, 'children': {}})}
        
        # Check if this partial path is a terminal suffix
        current_suffix = '.'.join(reversed(path))
        if current_suffix in suffixes:
            current[part]['is_terminal'] = True
            
        current = current[part]['children']

def generate_motoko_tree(node_dict, indent_level=2):
    if not node_dict:
        return ''
    
    indent = '  ' * indent_level
    entries = []
    
    for key in sorted(node_dict.keys()):
        node = node_dict[key]
        is_terminal = str(node['is_terminal']).lower()
        
        children_code = generate_motoko_tree(node['children'], indent_level + 1)
        
        entry = f'{indent}{{\\n{indent}  id = \"{key}\";\\n{indent}  isTerminal = {is_terminal};\\n{indent}  children = ['
        
        if children_code:
            entry += f'\\n{children_code}\\n{indent}  ];\\n{indent}}}'
        else:
            entry += f'];\\n{indent}}}'
            
        entries.append(entry)
    
    return ',\\n'.join(entries)

motoko_content = f'''module {{
  public type SuffixEntry = {{
    id : Text;
    isTerminal : Bool; // Can end here
    children : [SuffixEntry]; // Possible sub-suffixes
  }};

  public let value = [
{generate_motoko_tree(tree)}
  ];
}}'''

with open('$OUTPUT_FILE', 'w') as f:
    f.write(motoko_content)

print(f'Total suffixes processed: {len(suffixes)}')
print(f'Top-level domains: {len(tree)}')
"

# Check if output file was created successfully
if [ ! -f "$OUTPUT_FILE" ]; then
    echo "Error: Failed to create output file: $OUTPUT_FILE"
    rm -f "$TEMP_FILE" "$PROCESSED_FILE"
    exit 1
fi

# Clean up temporary files
rm -f "$TEMP_FILE" "$PROCESSED_FILE"

echo "Conversion complete! Motoko tree module saved to: $OUTPUT_FILE"

# Display some statistics
TOTAL_ENTRIES=$(grep -c 'id =' "$OUTPUT_FILE")
TERMINAL_ENTRIES=$(grep -c 'isTerminal = true' "$OUTPUT_FILE")
echo "Total entries processed: $TOTAL_ENTRIES"
echo "Terminal entries: $TERMINAL_ENTRIES"