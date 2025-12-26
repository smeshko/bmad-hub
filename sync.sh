#!/bin/bash
#
# BMAD Hub Sync Script
# Synchronizes the BMAD system from this hub to all registered projects
# Handles migration from alpha.15 (.bmad/_cfg) to alpha.19 (_bmad/_config)
#
# Usage:
#   ./sync.sh              # Sync all enabled projects
#   ./sync.sh --dry-run    # Preview changes without applying
#   ./sync.sh --list       # List all registered projects
#   ./sync.sh <name>       # Sync a specific project by name
#   ./sync.sh --help       # Show this help message

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color

# Script directory (hub root)
HUB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECTS_FILE="$HUB_DIR/projects.yaml"

# Flags
DRY_RUN=false
FORCE_SYNC=false
SPECIFIC_PROJECT=""
LIST_ONLY=false

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --dry-run|-n)
            DRY_RUN=true
            shift
            ;;
        --list|-l)
            LIST_ONLY=true
            shift
            ;;
        --force|-f)
            FORCE_SYNC=true
            shift
            ;;
        --help|-h)
            echo "BMAD Hub Sync Script"
            echo ""
            echo "Usage:"
            echo "  ./sync.sh              Sync projects that need updating"
            echo "  ./sync.sh --dry-run    Preview changes without applying"
            echo "  ./sync.sh --force      Force sync all projects, ignoring timestamps"
            echo "  ./sync.sh --list       List all registered projects"
            echo "  ./sync.sh <name>       Sync a specific project by name"
            echo "  ./sync.sh --help       Show this help message"
            echo ""
            echo "Options:"
            echo "  -n, --dry-run    Show what would be done without making changes"
            echo "  -f, --force      Ignore timestamps and sync all enabled projects"
            echo "  -l, --list       List all projects in projects.yaml"
            echo "  -h, --help       Show this help message"
            echo ""
            echo "Timestamp-based syncing:"
            echo "  The sync script tracks when each project was last synced."
            echo "  It compares this against the hub's latest modification time"
            echo "  and only syncs projects that are out of date."
            echo "  Use --force to sync regardless of timestamps."
            echo ""
            echo "Migration:"
            echo "  This script automatically detects and migrates alpha.15 installations"
            echo "  (.bmad/_cfg) to alpha.19 format (_bmad/_config)."
            echo ""
            echo "  Preserved during migration:"
            echo "    - Custom agents (bmad-custom module)"
            echo "    - Agent memory (.bmad-user-memory or .bmad/_memory)"
            echo "    - Custom agent customization files"
            echo "    - Project-specific hooks and ADW commands"
            exit 0
            ;;
        *)
            SPECIFIC_PROJECT="$1"
            shift
            ;;
    esac
done

# Check if projects.yaml exists
if [[ ! -f "$PROJECTS_FILE" ]]; then
    echo -e "${RED}Error: projects.yaml not found at $PROJECTS_FILE${NC}"
    exit 1
fi

# Check for yq (YAML parser)
if ! command -v yq &> /dev/null; then
    echo -e "${YELLOW}Warning: 'yq' not found. Installing via Homebrew...${NC}"
    if command -v brew &> /dev/null; then
        brew install yq
    else
        echo -e "${RED}Error: Please install 'yq' to parse YAML files${NC}"
        echo "  macOS: brew install yq"
        echo "  Linux: snap install yq or check https://github.com/mikefarah/yq"
        exit 1
    fi
fi

# Function to log messages
log() {
    echo -e "${BLUE}[BMAD Hub]${NC} $1"
}

log_success() {
    echo -e "${GREEN}✓${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

log_error() {
    echo -e "${RED}✗${NC} $1"
}

log_migrate() {
    echo -e "${MAGENTA}↗${NC} $1"
}

log_uptodate() {
    echo -e "${CYAN}○${NC} $1"
}

# Function to get the hub's latest modification timestamp (seconds since epoch)
# Scans _bmad/, .claude/commands/bmad/, .cursor/rules/bmad/, .gemini/commands/
get_hub_modified_timestamp() {
    local latest=0
    local dirs=("$HUB_DIR/_bmad" "$HUB_DIR/.claude/commands/bmad" "$HUB_DIR/.cursor/rules/bmad" "$HUB_DIR/.gemini/commands")

    for dir in "${dirs[@]}"; do
        if [[ -d "$dir" ]]; then
            # Find the most recently modified file in this directory
            local dir_latest
            if [[ "$(uname)" == "Darwin" ]]; then
                # macOS: use stat -f %m for modification time
                dir_latest=$(find "$dir" -type f -exec stat -f %m {} \; 2>/dev/null | sort -rn | head -1)
            else
                # Linux: use stat -c %Y
                dir_latest=$(find "$dir" -type f -exec stat -c %Y {} \; 2>/dev/null | sort -rn | head -1)
            fi

            if [[ -n "$dir_latest" ]] && [[ "$dir_latest" -gt "$latest" ]]; then
                latest="$dir_latest"
            fi
        fi
    done

    echo "$latest"
}

# Function to convert epoch seconds to ISO 8601 format
epoch_to_iso() {
    local epoch="$1"
    if [[ "$(uname)" == "Darwin" ]]; then
        date -r "$epoch" -u +"%Y-%m-%dT%H:%M:%SZ"
    else
        date -d "@$epoch" -u +"%Y-%m-%dT%H:%M:%SZ"
    fi
}

# Function to convert ISO 8601 to epoch seconds
iso_to_epoch() {
    local iso="$1"
    if [[ -z "$iso" ]] || [[ "$iso" == "null" ]]; then
        echo "0"
        return
    fi
    if [[ "$(uname)" == "Darwin" ]]; then
        # macOS date doesn't handle Z timezone suffix properly
        # Strip Z and use -u flag to parse as UTC
        local iso_no_z="${iso%Z}"
        TZ=UTC date -j -f "%Y-%m-%dT%H:%M:%S" "$iso_no_z" +%s 2>/dev/null || echo "0"
    else
        date -d "$iso" +%s 2>/dev/null || echo "0"
    fi
}

# Function to get a project's lastSynced timestamp (returns epoch seconds, 0 if never synced)
get_project_last_synced() {
    local index="$1"
    local last_synced=$(yq ".projects[$index].lastSynced // null" "$PROJECTS_FILE")
    iso_to_epoch "$last_synced"
}

# Function to update a project's lastSynced timestamp
update_project_last_synced() {
    local index="$1"
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    yq -i ".projects[$index].lastSynced = \"$timestamp\"" "$PROJECTS_FILE"
}

# Function to check if a project needs syncing
# Returns 0 (true) if sync needed, 1 (false) if up-to-date
project_needs_sync() {
    local index="$1"
    local hub_timestamp="$2"

    # If force sync is enabled, always return true
    if [[ "$FORCE_SYNC" == "true" ]]; then
        return 0
    fi

    local project_last_synced=$(get_project_last_synced "$index")

    # If never synced (0), needs sync
    if [[ "$project_last_synced" -eq 0 ]]; then
        return 0
    fi

    # If hub is newer than last sync, needs sync
    if [[ "$hub_timestamp" -gt "$project_last_synced" ]]; then
        return 0
    fi

    # Up to date
    return 1
}

# Function to detect BMAD installation type
# Returns: "alpha15" for .bmad/_cfg, "alpha19" for _bmad/_config, "none" for no installation
detect_bmad_version() {
    local path="$1"

    # Check for alpha.15 structure (.bmad with _cfg)
    if [[ -d "$path/.bmad" ]] && [[ -d "$path/.bmad/_cfg" ]]; then
        echo "alpha15"
        return
    fi

    # Check for alpha.19 structure (_bmad with _config)
    if [[ -d "$path/_bmad" ]] && [[ -d "$path/_bmad/_config" ]]; then
        echo "alpha19"
        return
    fi

    # Check for partial installations
    if [[ -d "$path/.bmad" ]]; then
        echo "alpha15-partial"
        return
    fi

    if [[ -d "$path/_bmad" ]]; then
        echo "alpha19-partial"
        return
    fi

    echo "none"
}

# Function to migrate alpha.15 to alpha.19
migrate_alpha15() {
    local path="$1"
    local backup_dir="$2"
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local backup_path="$path/$backup_dir/alpha15_$timestamp"

    echo ""
    log_migrate "${MAGENTA}Migrating from alpha.15 to alpha.19...${NC}"

    if [[ "$DRY_RUN" == "true" ]]; then
        log "Would create backup at: $backup_path"
        log "Would backup: .bmad/ -> $backup_path/.bmad/"

        if [[ -d "$path/.bmad-user-memory" ]]; then
            log "Would preserve: .bmad-user-memory/ -> _bmad/_memory/"
        fi

        if [[ -d "$path/.bmad/_memory" ]]; then
            log "Would preserve: .bmad/_memory/ -> _bmad/_memory/"
        fi

        if [[ -d "$path/.bmad/bmad-custom" ]]; then
            log "Would preserve: .bmad/bmad-custom/ -> _bmad/bmad-custom/"
        fi

        if [[ -d "$path/bmad-custom-src" ]]; then
            log "Would preserve: bmad-custom-src/ (kept in place)"
        fi

        # Check for custom agent customizations
        if [[ -d "$path/.bmad/_cfg/agents" ]]; then
            local custom_agents=$(find "$path/.bmad/_cfg/agents" -name "bmad-custom-*.customize.yaml" 2>/dev/null | wc -l | tr -d ' ')
            if [[ "$custom_agents" -gt 0 ]]; then
                log "Would preserve: $custom_agents custom agent customization file(s)"
            fi
        fi

        log "Would remove: .bmad/ (after backup)"
        return 0
    fi

    # Create backup directory
    mkdir -p "$backup_path"
    log "Created backup directory: $backup_path"

    # Backup entire .bmad folder
    log "Backing up .bmad/..."
    cp -r "$path/.bmad" "$backup_path/.bmad"
    log_success "Backed up .bmad/"

    # Backup .bmad-user-memory if exists
    if [[ -d "$path/.bmad-user-memory" ]]; then
        log "Backing up .bmad-user-memory/..."
        cp -r "$path/.bmad-user-memory" "$backup_path/.bmad-user-memory"
        log_success "Backed up .bmad-user-memory/"
    fi

    # Backup old IDE command folders
    if [[ -d "$path/.claude/commands/bmad" ]]; then
        mkdir -p "$backup_path/.claude/commands"
        cp -r "$path/.claude/commands/bmad" "$backup_path/.claude/commands/bmad"
        log_success "Backed up .claude/commands/bmad/"
    fi

    if [[ -d "$path/.cursor/rules/bmad" ]]; then
        mkdir -p "$backup_path/.cursor/rules"
        cp -r "$path/.cursor/rules/bmad" "$backup_path/.cursor/rules/bmad"
        log_success "Backed up .cursor/rules/bmad/"
    fi

    if [[ -d "$path/.gemini/commands" ]]; then
        mkdir -p "$backup_path/.gemini"
        # Only backup bmad-related files
        for file in "$path/.gemini/commands"/bmad-*.toml; do
            if [[ -f "$file" ]]; then
                mkdir -p "$backup_path/.gemini/commands"
                cp "$file" "$backup_path/.gemini/commands/"
            fi
        done
        if [[ -d "$backup_path/.gemini/commands" ]]; then
            log_success "Backed up .gemini/commands/bmad-*.toml"
        fi
    fi

    # Store paths to preserved content for later restoration
    PRESERVED_MEMORY=""
    PRESERVED_CUSTOM_MODULE=""
    PRESERVED_CUSTOM_AGENTS=()

    # Identify content to preserve
    if [[ -d "$path/.bmad-user-memory" ]]; then
        PRESERVED_MEMORY="$path/.bmad-user-memory"
    elif [[ -d "$path/.bmad/_memory" ]]; then
        PRESERVED_MEMORY="$backup_path/.bmad/_memory"
    fi

    if [[ -d "$path/.bmad/bmad-custom" ]]; then
        PRESERVED_CUSTOM_MODULE="$backup_path/.bmad/bmad-custom"
    fi

    # Find custom agent customization files
    if [[ -d "$path/.bmad/_cfg/agents" ]]; then
        while IFS= read -r -d '' file; do
            PRESERVED_CUSTOM_AGENTS+=("$file")
        done < <(find "$backup_path/.bmad/_cfg/agents" -name "bmad-custom-*.customize.yaml" -print0 2>/dev/null)
    fi

    # Remove old structure
    log "Removing old .bmad/ structure..."
    rm -rf "$path/.bmad"
    log_success "Removed old .bmad/"

    # Remove old .bmad-user-memory (will be restored to new location)
    if [[ -d "$path/.bmad-user-memory" ]]; then
        rm -rf "$path/.bmad-user-memory"
        log_success "Removed old .bmad-user-memory/ (will restore to _bmad/_memory/)"
    fi

    # Remove old IDE bmad folders (will be replaced)
    rm -rf "$path/.claude/commands/bmad" 2>/dev/null || true
    rm -rf "$path/.cursor/rules/bmad" 2>/dev/null || true
    # Remove old gemini bmad commands
    rm -f "$path/.gemini/commands"/bmad-*.toml 2>/dev/null || true

    log_success "Alpha.15 migration backup complete"
    log "Backup location: $backup_path"

    # Export preserved paths for use in sync
    export PRESERVED_MEMORY
    export PRESERVED_CUSTOM_MODULE
    export PRESERVED_CUSTOM_AGENTS

    return 0
}

# Function to migrate docs artifacts to _bmad-output structure
migrate_docs_artifacts() {
    local path="$1"
    local backup_dir="$2"
    local timestamp=$(date +%Y%m%d_%H%M%S)

    # Check if docs folder exists and has BMAD artifacts
    if [[ ! -d "$path/docs" ]]; then
        return 0
    fi

    # Check for any BMAD artifacts in docs/
    local has_artifacts=false
    [[ -f "$path/docs/prd.md" ]] && has_artifacts=true
    [[ -f "$path/docs/architecture.md" ]] && has_artifacts=true
    [[ -d "$path/docs/epics" ]] && has_artifacts=true
    [[ -d "$path/docs/sprint-artifacts" ]] && has_artifacts=true
    [[ -f "$path/docs/ux-design-specification.md" ]] && has_artifacts=true

    if [[ "$has_artifacts" == "false" ]]; then
        return 0
    fi

    echo ""
    log_migrate "Migrating docs artifacts to _bmad-output/..."

    # Create output directories
    local planning_dir="$path/_bmad-output/project-planning-artifacts"
    local impl_dir="$path/_bmad-output/implementation-artifacts"

    if [[ "$DRY_RUN" == "true" ]]; then
        log "Would create: $planning_dir"
        log "Would create: $impl_dir"
    else
        mkdir -p "$planning_dir"
        mkdir -p "$impl_dir"
    fi

    # Backup docs before migration
    local docs_backup="$path/$backup_dir/docs_artifacts_$timestamp"
    if [[ "$DRY_RUN" == "true" ]]; then
        log "Would backup docs artifacts to: $docs_backup"
    else
        mkdir -p "$docs_backup"
    fi

    # === PLANNING ARTIFACTS ===
    # PRD
    if [[ -f "$path/docs/prd.md" ]]; then
        if [[ "$DRY_RUN" == "true" ]]; then
            log "Would move: docs/prd.md -> _bmad-output/project-planning-artifacts/"
        else
            cp "$path/docs/prd.md" "$docs_backup/"
            mv "$path/docs/prd.md" "$planning_dir/"
            log_success "Moved prd.md to planning artifacts"
        fi
    fi

    # Architecture
    if [[ -f "$path/docs/architecture.md" ]]; then
        if [[ "$DRY_RUN" == "true" ]]; then
            log "Would move: docs/architecture.md -> _bmad-output/project-planning-artifacts/"
        else
            cp "$path/docs/architecture.md" "$docs_backup/"
            mv "$path/docs/architecture.md" "$planning_dir/"
            log_success "Moved architecture.md to planning artifacts"
        fi
    fi

    # UX Design
    if [[ -f "$path/docs/ux-design-specification.md" ]]; then
        if [[ "$DRY_RUN" == "true" ]]; then
            log "Would move: docs/ux-design-specification.md -> _bmad-output/project-planning-artifacts/"
        else
            cp "$path/docs/ux-design-specification.md" "$docs_backup/"
            mv "$path/docs/ux-design-specification.md" "$planning_dir/"
            log_success "Moved ux-design-specification.md to planning artifacts"
        fi
    fi

    # Epics folder
    if [[ -d "$path/docs/epics" ]]; then
        if [[ "$DRY_RUN" == "true" ]]; then
            log "Would move: docs/epics/ -> _bmad-output/project-planning-artifacts/epics/"
        else
            cp -r "$path/docs/epics" "$docs_backup/"
            mv "$path/docs/epics" "$planning_dir/"
            log_success "Moved epics/ to planning artifacts"
        fi
    fi

    # Analysis folder
    if [[ -d "$path/docs/analysis" ]]; then
        if [[ "$DRY_RUN" == "true" ]]; then
            log "Would move: docs/analysis/ -> _bmad-output/project-planning-artifacts/analysis/"
        else
            cp -r "$path/docs/analysis" "$docs_backup/"
            mv "$path/docs/analysis" "$planning_dir/"
            log_success "Moved analysis/ to planning artifacts"
        fi
    fi

    # Product brief files (pattern: product-brief*.md)
    for file in "$path/docs"/product-brief*.md; do
        if [[ -f "$file" ]]; then
            local filename=$(basename "$file")
            if [[ "$DRY_RUN" == "true" ]]; then
                log "Would move: docs/$filename -> _bmad-output/project-planning-artifacts/"
            else
                cp "$file" "$docs_backup/"
                mv "$file" "$planning_dir/"
                log_success "Moved $filename to planning artifacts"
            fi
        fi
    done

    # Tech spec files (pattern: tech-spec*.md)
    for file in "$path/docs"/tech-spec*.md; do
        if [[ -f "$file" ]]; then
            local filename=$(basename "$file")
            if [[ "$DRY_RUN" == "true" ]]; then
                log "Would move: docs/$filename -> _bmad-output/project-planning-artifacts/"
            else
                cp "$file" "$docs_backup/"
                mv "$file" "$planning_dir/"
                log_success "Moved $filename to planning artifacts"
            fi
        fi
    done

    # === IMPLEMENTATION ARTIFACTS ===
    # Sprint artifacts folder
    if [[ -d "$path/docs/sprint-artifacts" ]]; then
        if [[ "$DRY_RUN" == "true" ]]; then
            log "Would move: docs/sprint-artifacts/ -> _bmad-output/implementation-artifacts/"
        else
            cp -r "$path/docs/sprint-artifacts" "$docs_backup/"
            # Move contents, not the folder itself (to flatten structure)
            mkdir -p "$impl_dir"
            mv "$path/docs/sprint-artifacts"/* "$impl_dir/" 2>/dev/null || true
            rmdir "$path/docs/sprint-artifacts" 2>/dev/null || rm -rf "$path/docs/sprint-artifacts"
            log_success "Moved sprint-artifacts/ contents to implementation artifacts"
        fi
    fi

    # Stories folder (if separate from sprint-artifacts)
    if [[ -d "$path/docs/stories" ]]; then
        if [[ "$DRY_RUN" == "true" ]]; then
            log "Would move: docs/stories/ -> _bmad-output/implementation-artifacts/stories/"
        else
            cp -r "$path/docs/stories" "$docs_backup/"
            mv "$path/docs/stories" "$impl_dir/"
            log_success "Moved stories/ to implementation artifacts"
        fi
    fi

    # Sprint status file
    if [[ -f "$path/docs/sprint-status.yaml" ]]; then
        if [[ "$DRY_RUN" == "true" ]]; then
            log "Would move: docs/sprint-status.yaml -> _bmad-output/implementation-artifacts/"
        else
            cp "$path/docs/sprint-status.yaml" "$docs_backup/"
            mv "$path/docs/sprint-status.yaml" "$impl_dir/"
            log_success "Moved sprint-status.yaml to implementation artifacts"
        fi
    fi

    # BMM workflow status file
    if [[ -f "$path/docs/bmm-workflow-status.yaml" ]]; then
        if [[ "$DRY_RUN" == "true" ]]; then
            log "Would move: docs/bmm-workflow-status.yaml -> _bmad-output/"
        else
            cp "$path/docs/bmm-workflow-status.yaml" "$docs_backup/"
            mv "$path/docs/bmm-workflow-status.yaml" "$path/_bmad-output/"
            log_success "Moved bmm-workflow-status.yaml to _bmad-output/"
        fi
    fi

    # Clean up empty docs backup if nothing was backed up
    if [[ "$DRY_RUN" != "true" ]] && [[ -d "$docs_backup" ]]; then
        if [[ -z "$(ls -A "$docs_backup" 2>/dev/null)" ]]; then
            rmdir "$docs_backup"
        else
            log "Artifact backup location: $docs_backup"
        fi
    fi

    log_success "Docs artifact migration complete"
    return 0
}

# Function to restore preserved content after sync
restore_preserved_content() {
    local path="$1"

    # Restore agent memory
    if [[ -n "$PRESERVED_MEMORY" ]] && [[ -d "$PRESERVED_MEMORY" ]]; then
        log "Restoring agent memory to _bmad/_memory/..."
        if [[ "$DRY_RUN" != "true" ]]; then
            mkdir -p "$path/_bmad/_memory"
            cp -r "$PRESERVED_MEMORY"/* "$path/_bmad/_memory/" 2>/dev/null || true
            log_success "Restored agent memory"
        else
            log "Would restore agent memory to _bmad/_memory/"
        fi
    fi

    # Restore custom module
    if [[ -n "$PRESERVED_CUSTOM_MODULE" ]] && [[ -d "$PRESERVED_CUSTOM_MODULE" ]]; then
        log "Restoring custom module to _bmad/bmad-custom/..."
        if [[ "$DRY_RUN" != "true" ]]; then
            cp -r "$PRESERVED_CUSTOM_MODULE" "$path/_bmad/bmad-custom"
            log_success "Restored bmad-custom module"
        else
            log "Would restore bmad-custom module"
        fi
    fi

    # Restore custom agent customization files
    if [[ ${#PRESERVED_CUSTOM_AGENTS[@]} -gt 0 ]]; then
        log "Restoring ${#PRESERVED_CUSTOM_AGENTS[@]} custom agent customization file(s)..."
        if [[ "$DRY_RUN" != "true" ]]; then
            for file in "${PRESERVED_CUSTOM_AGENTS[@]}"; do
                if [[ -f "$file" ]]; then
                    cp "$file" "$path/_bmad/_config/agents/"
                fi
            done
            log_success "Restored custom agent customizations"
        else
            log "Would restore custom agent customization files"
        fi
    fi

    # Update manifest to include bmad-custom if it was restored
    if [[ -n "$PRESERVED_CUSTOM_MODULE" ]] && [[ -d "$path/_bmad/bmad-custom" ]]; then
        local manifest="$path/_bmad/_config/manifest.yaml"
        if [[ -f "$manifest" ]] && [[ "$DRY_RUN" != "true" ]]; then
            # Check if bmad-custom is already in modules
            if ! grep -q "bmad-custom" "$manifest"; then
                log "Adding bmad-custom to manifest..."
                if [[ "$(uname)" == "Darwin" ]]; then
                    sed -i '' 's/modules:/modules:\n  - bmad-custom/' "$manifest"
                else
                    sed -i 's/modules:/modules:\n  - bmad-custom/' "$manifest"
                fi
                log_success "Updated manifest with bmad-custom module"
            fi
        fi
    fi
}

# Function to list all projects
list_projects() {
    echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}                    BMAD Hub Projects                       ${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
    echo ""

    # Get hub modification timestamp
    local hub_timestamp=$(get_hub_modified_timestamp)
    local hub_iso=$(epoch_to_iso "$hub_timestamp")
    echo -e "Hub last modified: ${BLUE}$hub_iso${NC}"
    echo ""

    local count=$(yq '.projects | length' "$PROJECTS_FILE")

    if [[ "$count" == "0" ]] || [[ "$count" == "null" ]]; then
        echo "No projects registered. Add projects to projects.yaml"
        return
    fi

    for ((i=0; i<count; i++)); do
        local name=$(yq ".projects[$i].name" "$PROJECTS_FILE")
        local proj_path=$(yq ".projects[$i].path" "$PROJECTS_FILE")
        local enabled=$(yq ".projects[$i].enabled" "$PROJECTS_FILE")
        local desc=$(yq ".projects[$i].description // \"\"" "$PROJECTS_FILE")
        local last_synced=$(yq ".projects[$i].lastSynced // null" "$PROJECTS_FILE")

        if [[ "$enabled" == "true" ]]; then
            echo -e "${GREEN}●${NC} ${name}"
        else
            echo -e "${YELLOW}○${NC} ${name} ${YELLOW}(disabled)${NC}"
        fi
        echo "    Path: $proj_path"
        if [[ -n "$desc" && "$desc" != "null" ]]; then
            echo "    Description: $desc"
        fi

        # Show lastSynced and sync status
        if [[ "$last_synced" == "null" ]] || [[ -z "$last_synced" ]]; then
            echo -e "    Last synced: ${YELLOW}never${NC}"
        else
            local last_synced_epoch=$(iso_to_epoch "$last_synced")
            if [[ "$last_synced_epoch" -ge "$hub_timestamp" ]]; then
                echo -e "    Last synced: ${GREEN}$last_synced${NC} (up-to-date)"
            else
                echo -e "    Last synced: ${YELLOW}$last_synced${NC} (needs sync)"
            fi
        fi

        if [[ -d "$proj_path" ]]; then
            local version=$(detect_bmad_version "$proj_path")
            case $version in
                "alpha15")
                    echo -e "    BMAD: ${YELLOW}alpha.15 (.bmad/_cfg) - needs migration${NC}"
                    ;;
                "alpha19")
                    echo -e "    BMAD: ${GREEN}alpha.19 (_bmad/_config)${NC}"
                    ;;
                "alpha15-partial")
                    echo -e "    BMAD: ${YELLOW}alpha.15 partial installation${NC}"
                    ;;
                "alpha19-partial")
                    echo -e "    BMAD: ${YELLOW}alpha.19 partial installation${NC}"
                    ;;
                "none")
                    echo -e "    BMAD: ${BLUE}Not installed${NC}"
                    ;;
            esac
        else
            echo -e "    Status: ${RED}Directory not found${NC}"
        fi
        echo ""
    done
}

# Function to sync a single project
sync_project() {
    local name="$1"
    local path="$2"
    local ides="$3"

    echo ""
    echo -e "${CYAN}───────────────────────────────────────────────────────────${NC}"
    log "Syncing project: ${YELLOW}$name${NC}"
    echo -e "${CYAN}───────────────────────────────────────────────────────────${NC}"

    # Verify project path exists
    if [[ ! -d "$path" ]]; then
        log_error "Project directory does not exist: $path"
        return 1
    fi

    # Check if backup is enabled
    local backup_enabled=$(yq '.hub.backup_existing // true' "$PROJECTS_FILE")
    local backup_dir=$(yq '.hub.backup_dir // "_bmad-backup"' "$PROJECTS_FILE")

    # Detect current BMAD version
    local current_version=$(detect_bmad_version "$path")
    log "Detected BMAD installation: $current_version"

    # Reset preserved content variables
    PRESERVED_MEMORY=""
    PRESERVED_CUSTOM_MODULE=""
    PRESERVED_CUSTOM_AGENTS=()

    # Handle migration based on detected version
    case $current_version in
        "alpha15"|"alpha15-partial")
            log_warning "Alpha.15 installation detected - migration required"
            migrate_alpha15 "$path" "$backup_dir"
            ;;
        "alpha19"|"alpha19-partial")
            # Backup existing alpha.19 installation
            if [[ "$backup_enabled" == "true" ]]; then
                local backup_path="$path/$backup_dir"
                local timestamp=$(date +%Y%m%d_%H%M%S)
                local backup_target="$backup_path/bmad_$timestamp"

                if [[ "$DRY_RUN" == "true" ]]; then
                    log "Would backup existing _bmad to: $backup_target"
                else
                    log "Backing up existing installation..."
                    mkdir -p "$backup_path"
                    cp -r "$path/_bmad" "$backup_target"
                    log_success "Backup created: $backup_target"
                fi

                # Preserve memory and custom content from current installation
                if [[ -d "$path/_bmad/_memory" ]]; then
                    PRESERVED_MEMORY="$backup_target/_memory"
                fi
                if [[ -d "$path/_bmad/bmad-custom" ]]; then
                    PRESERVED_CUSTOM_MODULE="$backup_target/bmad-custom"
                fi
                # Find custom agent files
                if [[ -d "$path/_bmad/_config/agents" ]]; then
                    while IFS= read -r -d '' file; do
                        PRESERVED_CUSTOM_AGENTS+=("$file")
                    done < <(find "$backup_target/_config/agents" -name "bmad-custom-*.customize.yaml" -print0 2>/dev/null || true)
                fi
            fi

            # Remove old installation
            if [[ "$DRY_RUN" != "true" ]]; then
                rm -rf "$path/_bmad"
            fi
            ;;
        "none")
            log "Fresh installation - no migration needed"
            ;;
    esac

    # Determine which IDE folders to sync
    local sync_claude=false
    local sync_cursor=false
    local sync_gemini=false

    if [[ "$ides" == "null" ]] || [[ -z "$ides" ]]; then
        # Default: sync all
        sync_claude=true
        sync_cursor=true
        sync_gemini=true
    else
        [[ "$ides" == *"claude-code"* ]] && sync_claude=true
        [[ "$ides" == *"cursor"* ]] && sync_cursor=true
        [[ "$ides" == *"gemini"* ]] && sync_gemini=true
    fi

    # Sync _bmad folder
    if [[ "$DRY_RUN" == "true" ]]; then
        log "Would sync _bmad/ -> $path/_bmad/"
    else
        log "Syncing _bmad/..."
        cp -r "$HUB_DIR/_bmad" "$path/_bmad"
        log_success "Synced _bmad/"
    fi

    # Restore preserved content
    restore_preserved_content "$path"

    # Migrate docs artifacts to new _bmad-output structure
    migrate_docs_artifacts "$path" "$backup_dir"

    # Sync IDE-specific folders
    if [[ "$sync_claude" == "true" ]]; then
        if [[ "$DRY_RUN" == "true" ]]; then
            log "Would sync .claude/commands/bmad/ -> $path/.claude/commands/bmad/"
        else
            log "Syncing .claude/commands/bmad/..."
            mkdir -p "$path/.claude/commands"
            rm -rf "$path/.claude/commands/bmad"
            cp -r "$HUB_DIR/.claude/commands/bmad" "$path/.claude/commands/bmad"
            log_success "Synced .claude/commands/bmad/"
        fi
    fi

    if [[ "$sync_cursor" == "true" ]]; then
        if [[ "$DRY_RUN" == "true" ]]; then
            log "Would sync .cursor/rules/bmad/ -> $path/.cursor/rules/bmad/"
        else
            log "Syncing .cursor/rules/bmad/..."
            mkdir -p "$path/.cursor/rules"
            rm -rf "$path/.cursor/rules/bmad"
            cp -r "$HUB_DIR/.cursor/rules/bmad" "$path/.cursor/rules/bmad"
            log_success "Synced .cursor/rules/bmad/"
        fi
    fi

    if [[ "$sync_gemini" == "true" ]]; then
        if [[ "$DRY_RUN" == "true" ]]; then
            log "Would sync .gemini/commands/ -> $path/.gemini/commands/"
        else
            log "Syncing .gemini/commands/..."
            mkdir -p "$path/.gemini"
            rm -rf "$path/.gemini/commands"
            cp -r "$HUB_DIR/.gemini/commands" "$path/.gemini/commands"
            log_success "Synced .gemini/commands/"
        fi
    fi

    # Replace project name placeholder
    local config_file="$path/_bmad/bmm/config.yaml"
    if [[ -f "$config_file" ]]; then
        if [[ "$DRY_RUN" == "true" ]]; then
            log "Would replace 'insert-project-name-here' with '$name' in config.yaml"
        else
            log "Updating project name in config.yaml..."
            if [[ "$(uname)" == "Darwin" ]]; then
                # macOS
                sed -i '' "s/insert-project-name-here/$name/g" "$config_file"
            else
                # Linux
                sed -i "s/insert-project-name-here/$name/g" "$config_file"
            fi
            log_success "Updated project name to: $name"
        fi
    fi

    echo ""
    log_success "Project '$name' sync complete!"

    if [[ "$current_version" == "alpha15" ]] || [[ "$current_version" == "alpha15-partial" ]]; then
        echo ""
        log_warning "Migration notes:"
        echo "    - Old installation backed up to: $path/$backup_dir/"
        echo "    - Agent memory preserved in: _bmad/_memory/"
        echo "    - Custom modules preserved in: _bmad/bmad-custom/"
        echo "    - Planning artifacts moved to: _bmad-output/project-planning-artifacts/"
        echo "    - Implementation artifacts moved to: _bmad-output/implementation-artifacts/"
        echo "    - Review the backup if you need to recover anything"
    fi

    return 0
}

# Main execution
echo ""
echo -e "${CYAN}╔═══════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║              BMAD Hub Sync Tool (v6 alpha.19)             ║${NC}"
echo -e "${CYAN}╚═══════════════════════════════════════════════════════════╝${NC}"
echo ""

if [[ "$DRY_RUN" == "true" ]]; then
    echo -e "${YELLOW}>>> DRY RUN MODE - No changes will be made <<<${NC}"
    echo ""
fi

if [[ "$FORCE_SYNC" == "true" ]]; then
    echo -e "${YELLOW}>>> FORCE MODE - Ignoring timestamps <<<${NC}"
    echo ""
fi

# Get hub modification timestamp
HUB_TIMESTAMP=$(get_hub_modified_timestamp)
HUB_MODIFIED_ISO=$(epoch_to_iso "$HUB_TIMESTAMP")
log "Hub last modified: $HUB_MODIFIED_ISO"
echo ""

# Handle --list flag
if [[ "$LIST_ONLY" == "true" ]]; then
    list_projects
    exit 0
fi

# Get project count
PROJECT_COUNT=$(yq '.projects | length' "$PROJECTS_FILE")

if [[ "$PROJECT_COUNT" == "0" ]] || [[ "$PROJECT_COUNT" == "null" ]]; then
    log_warning "No projects found in projects.yaml"
    echo "Add projects to the 'projects' list in projects.yaml"
    exit 0
fi

# Track sync results
SYNCED=0
FAILED=0
SKIPPED=0
MIGRATED=0
UP_TO_DATE=0

# Sync specific project or all enabled projects
for ((i=0; i<PROJECT_COUNT; i++)); do
    name=$(yq ".projects[$i].name" "$PROJECTS_FILE")
    path=$(yq ".projects[$i].path" "$PROJECTS_FILE")
    enabled=$(yq ".projects[$i].enabled" "$PROJECTS_FILE")
    ides=$(yq ".projects[$i].ides // null" "$PROJECTS_FILE")

    # If specific project requested, only sync that one
    if [[ -n "$SPECIFIC_PROJECT" ]]; then
        if [[ "$name" == "$SPECIFIC_PROJECT" ]]; then
            current_ver=$(detect_bmad_version "$path")
            if sync_project "$name" "$path" "$ides"; then
                ((SYNCED++))
                [[ "$current_ver" == "alpha15"* ]] && ((MIGRATED++))
                # Update lastSynced timestamp
                if [[ "$DRY_RUN" != "true" ]]; then
                    update_project_last_synced "$i"
                fi
            else
                ((FAILED++))
            fi
            break
        fi
        continue
    fi

    # Skip disabled projects
    if [[ "$enabled" != "true" ]]; then
        log "Skipping disabled project: $name"
        ((SKIPPED++))
        continue
    fi

    # Check if project needs syncing (timestamp comparison)
    if ! project_needs_sync "$i" "$HUB_TIMESTAMP"; then
        log_uptodate "Project '$name' is up-to-date, skipping"
        ((UP_TO_DATE++))
        continue
    fi

    # Sync the project
    current_ver=$(detect_bmad_version "$path")
    if sync_project "$name" "$path" "$ides"; then
        ((SYNCED++))
        [[ "$current_ver" == "alpha15"* ]] && ((MIGRATED++))
        # Update lastSynced timestamp
        if [[ "$DRY_RUN" != "true" ]]; then
            update_project_last_synced "$i"
        fi
    else
        ((FAILED++))
    fi
done

# Handle case where specific project wasn't found
if [[ -n "$SPECIFIC_PROJECT" ]] && [[ $SYNCED -eq 0 ]] && [[ $FAILED -eq 0 ]]; then
    log_error "Project '$SPECIFIC_PROJECT' not found in projects.yaml"
    exit 1
fi

# Summary
echo ""
echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
echo -e "${CYAN}                         Summary                            ${NC}"
echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "  ${GREEN}Synced:${NC}     $SYNCED"
echo -e "  ${CYAN}Up-to-date:${NC} $UP_TO_DATE"
echo -e "  ${MAGENTA}Migrated:${NC}   $MIGRATED"
echo -e "  ${RED}Failed:${NC}     $FAILED"
echo -e "  ${YELLOW}Disabled:${NC}   $SKIPPED"
echo ""

if [[ "$DRY_RUN" == "true" ]]; then
    echo -e "${YELLOW}This was a dry run. Run without --dry-run to apply changes.${NC}"
fi

if [[ "$FORCE_SYNC" == "true" ]]; then
    echo -e "${YELLOW}Force mode was used - all projects were synced regardless of timestamps.${NC}"
fi

if [[ $MIGRATED -gt 0 ]] && [[ "$DRY_RUN" != "true" ]]; then
    echo -e "${MAGENTA}Note: $MIGRATED project(s) were migrated from alpha.15 to alpha.19${NC}"
    echo "Check _bmad-backup/ in each project for the original files."
fi

if [[ $UP_TO_DATE -gt 0 ]] && [[ "$FORCE_SYNC" != "true" ]]; then
    echo -e "${CYAN}Tip: Use --force to sync all projects regardless of timestamps.${NC}"
fi

if [[ $FAILED -gt 0 ]]; then
    exit 1
fi

exit 0
