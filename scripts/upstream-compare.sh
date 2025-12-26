#!/bin/bash
# upstream-compare.sh - Compare local BMAD files with upstream alpha.20
# Usage: ./scripts/upstream-compare.sh [workflow-path] [file]
# Example: ./scripts/upstream-compare.sh bmm/workflows/4-implementation/dev-story workflow.yaml

set -e

UPSTREAM_BASE="https://raw.githubusercontent.com/bmad-code-org/BMAD-METHOD/main/src/modules"
LOCAL_BASE="_bmad"
TEMP_DIR="/tmp/bmad-upstream-compare"

mkdir -p "$TEMP_DIR"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

show_help() {
    echo "Usage: $0 <workflow-path> [file]"
    echo ""
    echo "Examples:"
    echo "  $0 bmm/workflows/4-implementation/dev-story"
    echo "  $0 bmm/workflows/4-implementation/dev-story workflow.yaml"
    echo "  $0 bmm/workflows/4-implementation/create-story instructions.xml"
    echo ""
    echo "Common workflows to check:"
    echo "  bmm/workflows/4-implementation/dev-story"
    echo "  bmm/workflows/4-implementation/dev-begin"
    echo "  bmm/workflows/4-implementation/create-story"
    echo "  bmm/workflows/4-implementation/code-review"
}

compare_file() {
    local path=$1
    local file=$2
    local upstream_url="$UPSTREAM_BASE/$path/$file"
    local local_path="$LOCAL_BASE/$path/$file"
    local temp_file="$TEMP_DIR/$(echo $path | tr '/' '_')_$file"

    echo -e "${BLUE}Fetching upstream: $upstream_url${NC}"

    if curl -sf "$upstream_url" -o "$temp_file"; then
        if [ -f "$local_path" ]; then
            echo -e "${YELLOW}=== Diff: $local_path vs upstream ===${NC}"
            echo ""
            if diff -u "$local_path" "$temp_file" --color=always; then
                echo -e "${GREEN}✓ Files are identical${NC}"
            else
                echo ""
                echo -e "${YELLOW}Local file has differences from upstream${NC}"
            fi
        else
            echo -e "${RED}Local file not found: $local_path${NC}"
        fi
    else
        echo -e "${RED}Upstream file not found: $upstream_url${NC}"
    fi
}

list_workflow_files() {
    local path=$1
    echo -e "${BLUE}Listing files in $LOCAL_BASE/$path/${NC}"
    ls -la "$LOCAL_BASE/$path/" 2>/dev/null || echo "Directory not found"
}

if [ $# -eq 0 ]; then
    show_help
    exit 0
fi

WORKFLOW_PATH=$1
FILE=$2

if [ -z "$FILE" ]; then
    # List available files and compare common ones
    list_workflow_files "$WORKFLOW_PATH"
    echo ""
    echo -e "${YELLOW}Comparing common files...${NC}"
    echo ""

    for f in workflow.yaml workflow.md instructions.xml instructions.md; do
        if [ -f "$LOCAL_BASE/$WORKFLOW_PATH/$f" ]; then
            compare_file "$WORKFLOW_PATH" "$f"
            echo ""
            echo "---"
            echo ""
        fi
    done
else
    compare_file "$WORKFLOW_PATH" "$FILE"
fi
