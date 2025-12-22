# BMAD Hub

Central repository for BMAD Method installation management. This hub serves as the single source of truth for your BMAD system, allowing you to synchronize customizations across all your projects.

## Overview

```
hub/
├── .claude/commands/bmad/   # Claude Code IDE commands
├── .cursor/rules/bmad/      # Cursor IDE rules
├── .gemini/commands/        # Gemini IDE commands
├── _bmad/                   # Core BMAD installation
│   ├── _config/             # System configuration
│   ├── core/                # Base framework (bmad-master, brainstorming)
│   ├── bmm/                 # Main method (9 agents, 34+ workflows)
│   └── bmb/                 # Builder module (create agents/workflows)
├── projects.yaml            # Registry of projects to sync
├── sync.sh                  # Synchronization script
└── README.md                # This file
```

## Quick Start

### 1. Register Your Projects

Edit `projects.yaml` to add your projects:

```yaml
projects:
  - name: my-app
    path: /Users/A1E6E98/Developer/Projects/my-app
    enabled: true
    description: My main application

  - name: another-project
    path: /Users/A1E6E98/Developer/Projects/another-project
    enabled: true
    ides:
      - claude-code  # Only sync Claude Code (skip Cursor/Gemini)
```

### 2. Run the Sync Script

```bash
# Preview what will happen (recommended first run)
./sync.sh --dry-run

# Sync all enabled projects
./sync.sh

# Sync a specific project
./sync.sh my-app

# List all registered projects
./sync.sh --list
```

## Project Configuration

Each project entry in `projects.yaml` supports:

| Field | Required | Description |
|-------|----------|-------------|
| `name` | Yes | Project name (replaces placeholder in config) |
| `path` | Yes | Absolute path to project root |
| `enabled` | Yes | Whether to include in sync (`true`/`false`) |
| `description` | No | Brief project description |
| `ides` | No | Specific IDEs to sync (defaults to all) |

### IDE Selection

By default, all IDE folders are synced. To limit to specific IDEs:

```yaml
- name: my-project
  path: /path/to/project
  enabled: true
  ides:
    - claude-code  # .claude/commands/bmad/
    - cursor       # .cursor/rules/bmad/
    - gemini       # .gemini/commands/
```

## What Gets Synced

The sync script copies:

1. **`_bmad/`** - Complete BMAD installation
2. **`.claude/commands/bmad/`** - Claude Code commands
3. **`.cursor/rules/bmad/`** - Cursor rules
4. **`.gemini/commands/`** - Gemini commands

Additionally, the script:
- Replaces `insert-project-name-here` with the project name in `_bmad/bmm/config.yaml`
- Creates backups of existing installations (configurable)
- **Automatically migrates** alpha.15 installations to alpha.19 format

## Migration: Alpha.15 → Alpha.19

The sync script automatically detects and migrates older BMAD installations.

### What Changed Between Versions

| Component | Alpha.15 | Alpha.19 |
|-----------|----------|----------|
| Main folder | `.bmad/` | `_bmad/` |
| Config folder | `_cfg/` | `_config/` |
| Agent memory | `.bmad-user-memory/` or `.bmad/_memory/` | `_bmad/_memory/` |

**Why the change?** Dot-folders (`.bmad`) were being ignored by LLMs. The underscore prefix (`_bmad`) ensures AI agents can see and use the BMAD content.

### What Gets Preserved During Migration

- **Custom modules** (`bmad-custom/`) → restored to `_bmad/bmad-custom/`
- **Agent memory** → restored to `_bmad/_memory/`
- **Custom agent customizations** (`bmad-custom-*.customize.yaml`)
- **Project-specific hooks** (`.claude/hooks/`) - untouched
- **ADW commands** (`.claude/commands/adw/`) - untouched
- **bmad-custom-src/** - untouched (stays at project root)

### Artifact Location Changes

The sync script also migrates BMAD artifacts from `docs/` to the new `_bmad-output/` structure:

**Planning Artifacts** → `_bmad-output/project-planning-artifacts/`:
- `prd.md`
- `architecture.md`
- `ux-design-specification.md`
- `epics/`
- `analysis/`
- `product-brief*.md`
- `tech-spec*.md`

**Implementation Artifacts** → `_bmad-output/implementation-artifacts/`:
- `sprint-artifacts/*` (contents flattened)
- `stories/`
- `sprint-status.yaml`

**Workflow Tracking** → `_bmad-output/`:
- `bmm-workflow-status.yaml`

**Stays in `docs/`** (Project Knowledge):
- Reference documentation (e.g., `ios/`)
- `index.md`
- Any non-BMAD documentation

### What Gets Backed Up

Everything is backed up before migration:

**Alpha.15 Migration** → `_bmad-backup/alpha15_<timestamp>/`:
- `.bmad/` (complete old installation)
- `.bmad-user-memory/` (if exists)
- Old IDE command folders

**Artifact Migration** → `_bmad-backup/docs_artifacts_<timestamp>/`:
- All moved artifacts are copied here before moving

### Running a Dry-Run First

Always preview migrations before applying:

```bash
./sync.sh --dry-run
```

This shows exactly what would happen without making changes.

## Customization Workflow

1. **Make changes in the hub** - Edit agents, workflows, or configs here
2. **Test locally** if needed
3. **Run sync** to deploy to all projects

```bash
# Example: After modifying an agent in the hub
./sync.sh  # Updates all projects with your changes
```

## Hub Configuration

The `hub` section in `projects.yaml` controls sync behavior:

```yaml
hub:
  # Exclude these files/folders from sync
  exclude:
    - projects.yaml
    - sync.sh
    - README.md
    - .git
    - .DS_Store

  # Create backup before overwriting existing BMAD
  backup_existing: true

  # Backup directory name (relative to project root)
  backup_dir: _bmad-backup
```

## BMAD System Structure

### Modules

| Module | Purpose | Contents |
|--------|---------|----------|
| `core` | Base framework | bmad-master agent, brainstorming (62 methods), party-mode |
| `bmm` | Development method | 9 agents, 34+ workflows, 4-phase lifecycle |
| `bmb` | Builder tools | Create/edit agents, workflows, modules |

### Agents (BMM Module)

| Agent | Icon | Role |
|-------|------|------|
| Analyst | 🔍 | Market/domain/technical research |
| PM | 📊 | Product management & requirements |
| Architect | 🏗️ | Technical design & decisions |
| SM | 🎯 | Scrum master / agile management |
| DEV | 💻 | Development implementation |
| TEA | 🧪 | Test engineering & automation |
| UX Designer | 🎨 | User experience design |
| Tech Writer | 📝 | Documentation |
| Quick-Flow Solo Dev | ⚡ | Single-engineer fast mode |

### Workflow Phases

1. **Analysis** (Optional) - Research, product brief
2. **Planning** - PRD, UX design, tech specs
3. **Solutioning** - Architecture, epics & stories
4. **Implementation** - Sprint management, story development

## Troubleshooting

### "yq not found"
The script requires `yq` for YAML parsing:
```bash
brew install yq  # macOS
```

### Backup Location
Backups are stored in `<project>/_bmad-backup/` with timestamps.

### Sync Specific IDE Only
Use the `ides` field in project config to limit which IDE folders sync.

## Version

Based on BMAD Method v6.0.0-alpha.19
