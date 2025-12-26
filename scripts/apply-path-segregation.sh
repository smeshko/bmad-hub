#!/bin/bash
# apply-path-segregation.sh - Apply alpha.20 path segregation to workflow.yaml files
# This preserves local enhancements while updating path variables
#
# Usage: ./scripts/apply-path-segregation.sh [workflow-path]
# Example: ./scripts/apply-path-segregation.sh bmm/workflows/4-implementation/dev-story

set -e

LOCAL_BASE="_bmad"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

if [ $# -eq 0 ]; then
    echo "Usage: $0 <workflow-path>"
    echo "Example: $0 bmm/workflows/4-implementation/dev-story"
    exit 1
fi

WORKFLOW_PATH=$1
YAML_FILE="$LOCAL_BASE/$WORKFLOW_PATH/workflow.yaml"

if [ ! -f "$YAML_FILE" ]; then
    echo -e "${RED}File not found: $YAML_FILE${NC}"
    exit 1
fi

echo -e "${YELLOW}Applying path segregation to: $YAML_FILE${NC}"
echo ""

# Create backup
cp "$YAML_FILE" "$YAML_FILE.bak"
echo -e "${GREEN}✓ Backup created: $YAML_FILE.bak${NC}"

# Apply fixes using sed
# 1. Fix config path: .bmad -> _bmad
sed -i '' 's|{project-root}/\.bmad|{project-root}/_bmad|g' "$YAML_FILE"

# 2. Add implementation_artifacts if not present
if ! grep -q "implementation_artifacts:" "$YAML_FILE"; then
    # Add after config_source line
    sed -i '' '/^config_source:/a\
implementation_artifacts: "{config_source}:implementation_artifacts"
' "$YAML_FILE"
fi

# 3. Add planning_artifacts if not present (for workflows that need permanent docs)
if ! grep -q "planning_artifacts:" "$YAML_FILE"; then
    sed -i '' '/^implementation_artifacts:/a\
planning_artifacts: "{config_source}:planning_artifacts"
' "$YAML_FILE"
fi

# 4. Update sprint_artifacts references to implementation_artifacts
sed -i '' 's|sprint_artifacts|implementation_artifacts|g' "$YAML_FILE"

# 5. Add web_bundle: false if not present
if ! grep -q "web_bundle:" "$YAML_FILE"; then
    echo "" >> "$YAML_FILE"
    echo "web_bundle: false" >> "$YAML_FILE"
fi

echo -e "${GREEN}✓ Path segregation applied${NC}"
echo ""
echo "Changes made:"
echo "  - Fixed .bmad -> _bmad in paths"
echo "  - Added implementation_artifacts variable"
echo "  - Updated sprint_artifacts -> implementation_artifacts"
echo "  - Added web_bundle: false"
echo ""
echo -e "${YELLOW}Review the changes:${NC}"
diff --color "$YAML_FILE.bak" "$YAML_FILE" || true
