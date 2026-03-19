#!/bin/bash
#
# BMAD Hub Sync Script
# Synchronizes the BMAD system from this hub to all registered projects
# Supports v6.2.0 skills-based architecture (.claude/skills/)
# Handles migration from legacy formats (alpha.15, alpha.20 commands-based)
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

# Module-to-skill mapping (skills that belong to each module)
# Skills not listed here are assumed to be core module skills
BMB_SKILLS="bmad-agent-builder bmad-workflow-builder"
CIS_SKILLS="bmad-cis-design-thinking bmad-cis-innovation-strategy bmad-cis-problem-solving bmad-cis-storytelling"
TEA_SKILLS="bmad-teach-me-testing bmad-testarch-atdd bmad-testarch-automate bmad-testarch-ci bmad-testarch-framework bmad-testarch-nfr bmad-testarch-test-design bmad-testarch-test-review bmad-testarch-trace"

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
            echo "BMAD Hub Sync Script (v6.2.0)"
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
            echo "Per-project module selection:"
            echo "  Each project in projects.yaml can specify a 'modules' list to control"
            echo "  which modules are synced. Default: core + bmm (no bmb/cis/tea)."
            echo "  Example:"
            echo "    modules:"
            echo "      - core"
            echo "      - bmm"
            echo "      - tea"
            echo ""
            echo "Timestamp-based syncing:"
            echo "  The sync script tracks when each project was last synced."
            echo "  It compares this against the hub's latest modification time"
            echo "  and only syncs projects that are out of date."
            echo "  Use --force to sync regardless of timestamps."
            echo ""
            echo "Migration:"
            echo "  This script automatically detects and migrates legacy installations:"
            echo "    - alpha.15 (.bmad/_cfg) -> v6.2 (_bmad/_config + .claude/skills/)"
            echo "    - alpha.20 (.claude/commands/) -> v6.2 (.claude/skills/)"
            echo ""
            echo "  Preserved during migration:"
            echo "    - Custom agents (bmad-custom module)"
            echo "    - Agent memory (_bmad/_memory)"
            echo "    - Custom agent customization files"
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
# Scans _bmad/ and .claude/skills/
get_hub_modified_timestamp() {
    local latest=0
    local dirs=("$HUB_DIR/_bmad" "$HUB_DIR/.claude/skills")

    for dir in "${dirs[@]}"; do
        if [[ -d "$dir" ]]; then
            local dir_latest
            if [[ "$(uname)" == "Darwin" ]]; then
                dir_latest=$(find "$dir" -type f -exec stat -f %m {} \; 2>/dev/null | sort -rn | head -1)
            else
                dir_latest=$(find "$dir" -type f -exec stat -c %Y {} \; 2>/dev/null | sort -rn | head -1)
            fi

            if [[ -n "$dir_latest" ]] && [[ "$dir_latest" -gt "$latest" ]]; then
                latest="$dir_latest"
            fi
        fi
    done

    echo "$latest"
}

# Function to convert epoch seconds to ISO 8601 format (local timezone)
epoch_to_iso() {
    local epoch="$1"
    if [[ "$(uname)" == "Darwin" ]]; then
        date -r "$epoch" +"%Y-%m-%dT%H:%M:%S%z"
    else
        date -d "@$epoch" +"%Y-%m-%dT%H:%M:%S%z"
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
project_needs_sync() {
    local index="$1"
    local hub_timestamp="$2"

    if [[ "$FORCE_SYNC" == "true" ]]; then
        return 0
    fi

    local project_last_synced=$(get_project_last_synced "$index")

    if [[ "$project_last_synced" -eq 0 ]]; then
        return 0
    fi

    if [[ "$hub_timestamp" -gt "$project_last_synced" ]]; then
        return 0
    fi

    return 1
}

# Function to check if a skill belongs to a module
skill_belongs_to_module() {
    local skill_name="$1"
    local module="$2"

    case "$module" in
        bmb)
            [[ " $BMB_SKILLS " == *" $skill_name "* ]] && return 0
            ;;
        cis)
            [[ " $CIS_SKILLS " == *" $skill_name "* ]] && return 0
            ;;
        tea)
            [[ " $TEA_SKILLS " == *" $skill_name "* ]] && return 0
            ;;
    esac
    return 1
}

# Function to check if a module should be synced for a project
should_sync_module() {
    local module="$1"
    local modules_csv="$2"

    # core is always synced
    if [[ "$module" == "core" ]]; then
        return 0
    fi

    # If no modules specified, default to core + bmm only
    if [[ -z "$modules_csv" ]] || [[ "$modules_csv" == "null" ]]; then
        [[ "$module" == "bmm" ]] && return 0
        return 1
    fi

    # Check if module is in the list
    [[ " $modules_csv " == *" $module "* ]] && return 0
    return 1
}

# Function to detect BMAD installation type
# Returns: "alpha15", "alpha20-commands", "v6-skills", "alpha20-partial", "none"
detect_bmad_version() {
    local path="$1"

    # Check for alpha.15 structure (.bmad with _cfg)
    if [[ -d "$path/.bmad" ]] && [[ -d "$path/.bmad/_cfg" ]]; then
        echo "alpha15"
        return
    fi

    # Check for v6.2 skills-based structure
    if [[ -d "$path/_bmad" ]] && [[ -d "$path/_bmad/_config" ]] && [[ -d "$path/.claude/skills" ]]; then
        echo "v6-skills"
        return
    fi

    # Check for alpha.20 commands-based structure
    if [[ -d "$path/_bmad" ]] && [[ -d "$path/_bmad/_config" ]] && [[ -d "$path/.claude/commands/bmad" ]]; then
        echo "alpha20-commands"
        return
    fi

    # Check for alpha.20 structure without IDE folders
    if [[ -d "$path/_bmad" ]] && [[ -d "$path/_bmad/_config" ]]; then
        echo "alpha20"
        return
    fi

    # Check for partial installations
    if [[ -d "$path/.bmad" ]]; then
        echo "alpha15-partial"
        return
    fi

    if [[ -d "$path/_bmad" ]]; then
        echo "alpha20-partial"
        return
    fi

    echo "none"
}

# Function to migrate alpha.15 to current format
migrate_alpha15() {
    local path="$1"
    local backup_dir="$2"
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local backup_path="$path/$backup_dir/alpha15_$timestamp"

    echo ""
    log_migrate "${MAGENTA}Migrating from alpha.15...${NC}"

    if [[ "$DRY_RUN" == "true" ]]; then
        log "Would create backup at: $backup_path"
        log "Would backup: .bmad/ -> $backup_path/.bmad/"
        [[ -d "$path/.bmad-user-memory" ]] && log "Would preserve: .bmad-user-memory/ -> _bmad/_memory/"
        [[ -d "$path/.bmad/_memory" ]] && log "Would preserve: .bmad/_memory/ -> _bmad/_memory/"
        [[ -d "$path/.bmad/bmad-custom" ]] && log "Would preserve: .bmad/bmad-custom/ -> _bmad/bmad-custom/"
        log "Would remove: .bmad/ and .claude/commands/bmad/ (after backup)"
        return 0
    fi

    mkdir -p "$backup_path"
    log "Created backup directory: $backup_path"

    cp -r "$path/.bmad" "$backup_path/.bmad"
    log_success "Backed up .bmad/"

    if [[ -d "$path/.bmad-user-memory" ]]; then
        cp -r "$path/.bmad-user-memory" "$backup_path/.bmad-user-memory"
        log_success "Backed up .bmad-user-memory/"
    fi

    if [[ -d "$path/.claude/commands/bmad" ]]; then
        mkdir -p "$backup_path/.claude/commands"
        cp -r "$path/.claude/commands/bmad" "$backup_path/.claude/commands/bmad"
        log_success "Backed up .claude/commands/bmad/"
    fi

    # Store paths to preserved content for later restoration
    PRESERVED_MEMORY=""
    PRESERVED_CUSTOM_MODULE=""
    PRESERVED_CUSTOM_AGENTS=()

    if [[ -d "$path/.bmad-user-memory" ]]; then
        PRESERVED_MEMORY="$path/.bmad-user-memory"
    elif [[ -d "$path/.bmad/_memory" ]]; then
        PRESERVED_MEMORY="$backup_path/.bmad/_memory"
    fi

    [[ -d "$path/.bmad/bmad-custom" ]] && PRESERVED_CUSTOM_MODULE="$backup_path/.bmad/bmad-custom"

    if [[ -d "$path/.bmad/_cfg/agents" ]]; then
        while IFS= read -r -d '' file; do
            PRESERVED_CUSTOM_AGENTS+=("$file")
        done < <(find "$backup_path/.bmad/_cfg/agents" -name "bmad-custom-*.customize.yaml" -print0 2>/dev/null)
    fi

    rm -rf "$path/.bmad"
    log_success "Removed old .bmad/"

    if [[ -d "$path/.bmad-user-memory" ]]; then
        rm -rf "$path/.bmad-user-memory"
        log_success "Removed old .bmad-user-memory/ (will restore to _bmad/_memory/)"
    fi

    rm -rf "$path/.claude/commands/bmad" 2>/dev/null || true

    log_success "Alpha.15 migration backup complete"
    log "Backup location: $backup_path"

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

    if [[ ! -d "$path/docs" ]]; then
        return 0
    fi

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

    local planning_dir="$path/_bmad-output/project-planning-artifacts"
    local impl_dir="$path/_bmad-output/implementation-artifacts"

    if [[ "$DRY_RUN" == "true" ]]; then
        log "Would create: $planning_dir"
        log "Would create: $impl_dir"
    else
        mkdir -p "$planning_dir"
        mkdir -p "$impl_dir"
    fi

    local docs_backup="$path/$backup_dir/docs_artifacts_$timestamp"
    if [[ "$DRY_RUN" != "true" ]]; then
        mkdir -p "$docs_backup"
    fi

    # Planning artifacts
    for file in "$path/docs"/prd.md "$path/docs"/architecture.md "$path/docs"/ux-design-specification.md; do
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

    for dir in "$path/docs/epics" "$path/docs/analysis"; do
        if [[ -d "$dir" ]]; then
            local dirname=$(basename "$dir")
            if [[ "$DRY_RUN" == "true" ]]; then
                log "Would move: docs/$dirname/ -> _bmad-output/project-planning-artifacts/$dirname/"
            else
                cp -r "$dir" "$docs_backup/"
                mv "$dir" "$planning_dir/"
                log_success "Moved $dirname/ to planning artifacts"
            fi
        fi
    done

    for file in "$path/docs"/product-brief*.md "$path/docs"/tech-spec*.md; do
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

    # Implementation artifacts
    if [[ -d "$path/docs/sprint-artifacts" ]]; then
        if [[ "$DRY_RUN" == "true" ]]; then
            log "Would move: docs/sprint-artifacts/ -> _bmad-output/implementation-artifacts/"
        else
            cp -r "$path/docs/sprint-artifacts" "$docs_backup/"
            mkdir -p "$impl_dir"
            mv "$path/docs/sprint-artifacts"/* "$impl_dir/" 2>/dev/null || true
            rmdir "$path/docs/sprint-artifacts" 2>/dev/null || rm -rf "$path/docs/sprint-artifacts"
            log_success "Moved sprint-artifacts/ contents to implementation artifacts"
        fi
    fi

    if [[ -d "$path/docs/stories" ]]; then
        if [[ "$DRY_RUN" == "true" ]]; then
            log "Would move: docs/stories/ -> _bmad-output/implementation-artifacts/stories/"
        else
            cp -r "$path/docs/stories" "$docs_backup/"
            mv "$path/docs/stories" "$impl_dir/"
            log_success "Moved stories/ to implementation artifacts"
        fi
    fi

    if [[ -f "$path/docs/sprint-status.yaml" ]]; then
        if [[ "$DRY_RUN" == "true" ]]; then
            log "Would move: docs/sprint-status.yaml -> _bmad-output/implementation-artifacts/"
        else
            cp "$path/docs/sprint-status.yaml" "$docs_backup/"
            mv "$path/docs/sprint-status.yaml" "$impl_dir/"
            log_success "Moved sprint-status.yaml to implementation artifacts"
        fi
    fi

    if [[ -f "$path/docs/bmm-workflow-status.yaml" ]]; then
        if [[ "$DRY_RUN" == "true" ]]; then
            log "Would move: docs/bmm-workflow-status.yaml -> _bmad-output/"
        else
            cp "$path/docs/bmm-workflow-status.yaml" "$docs_backup/"
            mv "$path/docs/bmm-workflow-status.yaml" "$path/_bmad-output/"
            log_success "Moved bmm-workflow-status.yaml to _bmad-output/"
        fi
    fi

    # Clean up empty docs backup
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

    if [[ -n "$PRESERVED_CUSTOM_MODULE" ]] && [[ -d "$PRESERVED_CUSTOM_MODULE" ]]; then
        log "Restoring custom module to _bmad/bmad-custom/..."
        if [[ "$DRY_RUN" != "true" ]]; then
            cp -r "$PRESERVED_CUSTOM_MODULE" "$path/_bmad/bmad-custom"
            log_success "Restored bmad-custom module"
        else
            log "Would restore bmad-custom module"
        fi
    fi

    if [[ ${#PRESERVED_CUSTOM_AGENTS[@]} -gt 0 ]]; then
        log "Restoring ${#PRESERVED_CUSTOM_AGENTS[@]} custom agent customization file(s)..."
        if [[ "$DRY_RUN" != "true" ]]; then
            for file in "${PRESERVED_CUSTOM_AGENTS[@]}"; do
                [[ -f "$file" ]] && cp "$file" "$path/_bmad/_config/agents/"
            done
            log_success "Restored custom agent customizations"
        else
            log "Would restore custom agent customization files"
        fi
    fi

    if [[ -n "$PRESERVED_CUSTOM_MODULE" ]] && [[ -d "$path/_bmad/bmad-custom" ]]; then
        local manifest="$path/_bmad/_config/manifest.yaml"
        if [[ -f "$manifest" ]] && [[ "$DRY_RUN" != "true" ]]; then
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
        local modules=$(yq ".projects[$i].modules // null" "$PROJECTS_FILE")

        if [[ "$enabled" == "true" ]]; then
            echo -e "${GREEN}●${NC} ${name}"
        else
            echo -e "${YELLOW}○${NC} ${name} ${YELLOW}(disabled)${NC}"
        fi
        echo "    Path: $proj_path"
        if [[ -n "$desc" && "$desc" != "null" ]]; then
            echo "    Description: $desc"
        fi

        # Show modules
        if [[ "$modules" != "null" ]] && [[ -n "$modules" ]]; then
            local mod_list=$(yq ".projects[$i].modules[]" "$PROJECTS_FILE" 2>/dev/null | tr '\n' ', ' | sed 's/,$//')
            echo -e "    Modules: ${BLUE}$mod_list${NC}"
        else
            echo -e "    Modules: ${BLUE}core, bmm${NC} (default)"
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
                "alpha20-commands")
                    echo -e "    BMAD: ${YELLOW}alpha.20 (.claude/commands) - needs migration to skills${NC}"
                    ;;
                "v6-skills")
                    echo -e "    BMAD: ${GREEN}v6.2 (skills-based)${NC}"
                    ;;
                "alpha20")
                    echo -e "    BMAD: ${YELLOW}alpha.20 (_bmad/_config)${NC}"
                    ;;
                "alpha15-partial"|"alpha20-partial")
                    echo -e "    BMAD: ${YELLOW}partial installation${NC}"
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
    local modules_csv="$4"

    echo ""
    echo -e "${CYAN}───────────────────────────────────────────────────────────${NC}"
    log "Syncing project: ${YELLOW}$name${NC}"
    echo -e "${CYAN}───────────────────────────────────────────────────────────${NC}"

    # Verify project path exists
    if [[ ! -d "$path" ]]; then
        log_error "Project directory does not exist: $path"
        return 1
    fi

    local backup_enabled=$(yq '.hub.backup_existing // true' "$PROJECTS_FILE")
    local backup_dir=$(yq '.hub.backup_dir // "_bmad-backup"' "$PROJECTS_FILE")

    local current_version=$(detect_bmad_version "$path")
    log "Detected BMAD installation: $current_version"

    if [[ -n "$modules_csv" ]] && [[ "$modules_csv" != "null" ]]; then
        log "Modules to sync: $modules_csv"
    else
        log "Modules to sync: core bmm (default)"
    fi

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
        "alpha20-commands"|"alpha20"|"alpha20-partial"|"v6-skills")
            # Backup existing installation
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

                # Preserve memory and custom content
                [[ -d "$path/_bmad/_memory" ]] && PRESERVED_MEMORY="$backup_target/_memory"
                [[ -d "$path/_bmad/bmad-custom" ]] && PRESERVED_CUSTOM_MODULE="$backup_target/bmad-custom"
                if [[ -d "$path/_bmad/_config/agents" ]]; then
                    while IFS= read -r -d '' file; do
                        PRESERVED_CUSTOM_AGENTS+=("$file")
                    done < <(find "$backup_target/_config/agents" -name "bmad-custom-*.customize.yaml" -print0 2>/dev/null || true)
                fi
            fi

            # Remove old installation
            if [[ "$DRY_RUN" != "true" ]]; then
                rm -rf "$path/_bmad"
                # Clean up legacy IDE folders
                rm -rf "$path/.claude/commands/bmad" 2>/dev/null || true
            fi
            ;;
        "none")
            log "Fresh installation - no migration needed"
            ;;
    esac

    # Determine which IDE folders to sync
    local sync_claude=false

    if [[ "$ides" == "null" ]] || [[ -z "$ides" ]]; then
        sync_claude=true
    else
        [[ "$ides" == *"claude-code"* ]] && sync_claude=true
    fi

    # === Sync _bmad folder (module-aware) ===
    if [[ "$DRY_RUN" == "true" ]]; then
        log "Would sync _bmad/ -> $path/_bmad/"
    else
        log "Syncing _bmad/..."
        # Copy core first (always)
        mkdir -p "$path/_bmad"
        cp -r "$HUB_DIR/_bmad/_config" "$path/_bmad/_config"
        cp -r "$HUB_DIR/_bmad/core" "$path/_bmad/core"
        log_success "Synced _bmad/core/"

        # Sync each module based on project config
        for module_dir in "$HUB_DIR/_bmad"/*/; do
            local module_name=$(basename "$module_dir")
            # Skip _config, _memory, core (already copied)
            [[ "$module_name" == "_config" ]] && continue
            [[ "$module_name" == "_memory" ]] && continue
            [[ "$module_name" == "core" ]] && continue

            if should_sync_module "$module_name" "$modules_csv"; then
                cp -r "$module_dir" "$path/_bmad/$module_name"
                log_success "Synced _bmad/$module_name/"
            else
                log "Skipped _bmad/$module_name/ (not in project modules)"
            fi
        done
    fi

    # Restore preserved content
    restore_preserved_content "$path"

    # Migrate docs artifacts to new _bmad-output structure
    migrate_docs_artifacts "$path" "$backup_dir"

    # === Sync .claude/skills/ (module-aware) ===
    if [[ "$sync_claude" == "true" ]]; then
        if [[ "$DRY_RUN" == "true" ]]; then
            log "Would sync .claude/skills/ -> $path/.claude/skills/"
        else
            log "Syncing .claude/skills/..."
            mkdir -p "$path/.claude/skills"
            # Remove old bmad skills (will be replaced)
            rm -rf "$path/.claude/skills"/bmad-* 2>/dev/null || true

            local synced_count=0
            local skipped_count=0

            for skill_dir in "$HUB_DIR/.claude/skills"/bmad-*/; do
                local skill_name=$(basename "$skill_dir")
                local skip=false

                # Check if skill belongs to an excluded module
                if ! should_sync_module "bmb" "$modules_csv" && skill_belongs_to_module "$skill_name" "bmb"; then
                    skip=true
                fi
                if ! should_sync_module "cis" "$modules_csv" && skill_belongs_to_module "$skill_name" "cis"; then
                    skip=true
                fi
                if ! should_sync_module "tea" "$modules_csv" && skill_belongs_to_module "$skill_name" "tea"; then
                    skip=true
                fi

                if [[ "$skip" == "true" ]]; then
                    ((skipped_count++))
                else
                    cp -r "$skill_dir" "$path/.claude/skills/$skill_name"
                    ((synced_count++))
                fi
            done

            log_success "Synced $synced_count skills (skipped $skipped_count from excluded modules)"
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
                sed -i '' "s/insert-project-name-here/$name/g" "$config_file"
            else
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

    if [[ "$current_version" == "alpha20-commands" ]]; then
        echo ""
        log_warning "Migrated from commands to skills:"
        echo "    - Old .claude/commands/bmad/ has been removed"
        echo "    - New .claude/skills/bmad-*/ installed"
    fi

    return 0
}

# Main execution
echo ""
echo -e "${CYAN}╔═══════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║              BMAD Hub Sync Tool (v6.2.0)                  ║${NC}"
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
    # Read modules list as space-separated string
    modules=$(yq ".projects[$i].modules // null" "$PROJECTS_FILE")
    if [[ "$modules" != "null" ]]; then
        modules=$(yq ".projects[$i].modules[]" "$PROJECTS_FILE" 2>/dev/null | tr '\n' ' ' | sed 's/ $//')
    fi

    # If specific project requested, only sync that one
    if [[ -n "$SPECIFIC_PROJECT" ]]; then
        if [[ "$name" == "$SPECIFIC_PROJECT" ]]; then
            current_ver=$(detect_bmad_version "$path")
            if sync_project "$name" "$path" "$ides" "$modules"; then
                ((SYNCED++))
                [[ "$current_ver" == "alpha15"* ]] && ((MIGRATED++))
                [[ "$current_ver" == "alpha20-commands" ]] && ((MIGRATED++))
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
    if sync_project "$name" "$path" "$ides" "$modules"; then
        ((SYNCED++))
        [[ "$current_ver" == "alpha15"* ]] && ((MIGRATED++))
        [[ "$current_ver" == "alpha20-commands" ]] && ((MIGRATED++))
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
    echo -e "${MAGENTA}Note: $MIGRATED project(s) were migrated to v6.2 skills format${NC}"
    echo "Check _bmad-backup/ in each project for the original files."
fi

if [[ $UP_TO_DATE -gt 0 ]] && [[ "$FORCE_SYNC" != "true" ]]; then
    echo -e "${CYAN}Tip: Use --force to sync all projects regardless of timestamps.${NC}"
fi

if [[ $FAILED -gt 0 ]]; then
    exit 1
fi

exit 0
