---
stepsCompleted: [1, 2, 3, 4, 5, 6, 7, 8, 9]
status: COMPLETE
completionDate: 2025-12-21
---

# Workflow Creation Plan: project-config

## Initial Project Context

- **Module:** bmm (setup folder)
- **Target Location:** `_bmad/bmm/workflows/setup/project-config/`
- **Created:** 2025-12-21

## Workflow Purpose

Create a configuration workflow that generates a project-level config file (`_bmad/project-config.yaml`) enabling other workflows (test, document, ship) to operate in a generic, config-driven manner across different project types (web, backend, mobile, etc.).

## Related Workflows (to be created)

| Workflow | Depends On | Purpose |
|----------|------------|---------|
| `project-config` | - | Creates the config file |
| `test` | project-config | Runs all tests/linting per config |
| `document` | project-config | Verifies & updates docs per config |
| `ship` | project-config | Deploys/releases per config |

## Config File Structure (Draft)

```yaml
# _bmad/project-config.yaml
project:
  name: "my-project"
  type: web | backend | mobile | monorepo | other

test:
  pre_commands: []
  unit:
    command: "npm test"
    enabled: true
  e2e:
    command: "npm run test:e2e"
    enabled: true
  lint:
    command: "npm run lint"
    enabled: true
  typecheck:
    command: "npm run typecheck"
    enabled: true
  custom: []

document:
  standards_file: "docs/DOCUMENTATION_STANDARDS.md"
  check_inline: true
  check_external: true
  doc_locations:
    - "README.md"
    - "docs/"
    - "API.md"
  patterns: []

ship:
  pre_checks: []
  type: npm | docker | github-release | custom
  commands:
    version_bump: "npm version patch"
    build: "npm run build"
    publish: "npm publish"
    post_publish: []
  environments:
    staging: {}
    production: {}
```

## Pipeline Context

Part of 6-step workflow: **plan → build → test → review → document → ship**

---

## Gathered Requirements

### Workflow Classification

- **Type**: Document workflow (generates YAML config file)
- **Instruction Style**: Mixed - prescriptive for detection/validation, intent-based for conversation

### Interaction Model

- **Style**: Wizard with proposed defaults based on detection
- **User confirms/adjusts** each section before saving

### Detection Strategy

Deep scan on initialization:
- **Project type files**: package.json, Podfile, *.xcodeproj, build.gradle, pom.xml, requirements.txt, pyproject.toml, go.mod, Cargo.toml
- **Tooling configs**: .eslintrc, jest.config, playwright.config, vitest.config, tsconfig.json, .prettierrc, and similar
- Extract commands from package.json scripts, Makefile targets, etc.

### Config Sections

| Section | Required | Notes |
|---------|----------|-------|
| project | Yes | Name, type - always captured |
| test | No | Unit, e2e, lint, typecheck, custom commands |
| document | No | Standards file, doc locations, patterns |
| ship | No | Deployment type, commands, environments |

### Existing Config Handling

- **Smart detection**: If config exists, analyze what's already configured
- **Offer options**: Add missing sections, modify existing sections, or full reconfigure
- **Not always override**: Be intelligent about preserving user's existing work

### Unknown Project Structure

- **No guessing**: If structure is unrecognizable, ask user to describe
- **No default suggestions**: Let user tell you about their setup
- **Monorepos**: User decides how to handle (single config vs per-project)

### Validation

- **Run quick tests**: Execute configured commands to verify they work
- **Suggest fixes**: If commands fail, analyze output and recommend corrections
- **User approval**: Don't auto-fix, let user decide

### Output

- **Single file**: `_bmad/project-config.yaml`
- **No summary report**

### Invocation

- **Slash command**: Create Claude slash command to invoke the workflow (e.g., `/project-config` or `/setup-project`)

---

## Tools Configuration

### Core BMAD Tools

- **Party-Mode**: Excluded
- **Advanced Elicitation**: Included
  - Integration points: Ambiguous/unrecognizable project structure, validation failures requiring troubleshooting
- **Brainstorming**: Excluded

### LLM Features

- **Web-Browsing**: Excluded
- **File I/O**: Required - Read project files (package.json, configs, etc.), write config file
- **Sub-Agents**: Included
  - Integration points: Parallel scanning (project type + tooling configs), parallel command validation
- **Sub-Processes**: Required - Execute and validate configured commands

### Memory Systems

- **Sidecar File**: Excluded - Config file itself serves as persistent state

### External Integrations

- None required

### Installation Requirements

- None - all selected tools are built-in BMAD/LLM capabilities

---

## Output Format Design

**Format Type**: Strict Template (YAML schema)

**Output Requirements**:
- Document type: YAML configuration file
- File format: .yaml
- Location: `_bmad/project-config.yaml`
- Frequency: Single file, created/updated per project

**Structure Specifications**:

```yaml
project:
  name: string
  type: web | backend | mobile | monorepo | other

test:
  pre_commands: []
  unit: { command: string, enabled: boolean }
  e2e: { command: string, enabled: boolean }
  lint: { command: string, enabled: boolean }
  typecheck: { command: string, enabled: boolean }
  custom: []

document:
  standards_file: string
  check_inline: boolean
  check_external: boolean
  doc_locations: []
  patterns: []

ship:
  pre_checks: []
  type: npm | docker | github-release | custom
  commands: { version_bump: string, build: string, publish: string, post_publish: [] }
  environments: { staging: {}, production: {} }
```

**Validation Rules**:
- No required fields within sections (all optional)
- Sections themselves are optional (except `project`)

**Formatting**:
- Clean YAML only, no inline comments
- No section headers or documentation in output

---

## Workflow Structure Design

### Step Structure

| File | Purpose |
|------|---------|
| `step-01-init.md` | Check for existing config, route to 1b or 2 |
| `step-01b-continue.md` | Handle existing config (add/modify/reconfigure) |
| `step-02-scan.md` | Deep scan project using sub-agents, present findings |
| `step-03-configure.md` | Walk through all sections, validate commands as you go |
| `step-04-save.md` | Final review, save config file |

### Flow Logic

```
[Start]
    │
    ▼
Step 1: Init
    │
    ├─── Config exists ───▶ Step 1b: Continue
    │                           ├─ Add sections ──────▶ Step 3
    │                           ├─ Modify sections ───▶ Step 3
    │                           └─ Full reconfigure ──▶ Step 2
    │
    └─── No config ───────▶ Step 2: Scan
                               │
                               ▼
                           Step 3: Configure
                               │
                               ▼
                           Step 4: Save
                               │
                               ▼
                           [Complete]
```

### Interaction Patterns

| Step | Menu | Interaction Style |
|------|------|-------------------|
| 1 | Auto-proceed | No user input, routing only |
| 1b | [A]dd / [M]odify / [R]econfigure | User chooses path |
| 2 | A/P/C | Present findings, user confirms |
| 3 | A/P/C per section + [S]kip | Wizard through sections |
| 4 | [E]dit / [S]ave | Final review |

### File Structure

```
_bmad/bmm/workflows/setup/project-config/
├── workflow.md
├── steps/
│   ├── step-01-init.md
│   ├── step-01b-continue.md
│   ├── step-02-scan.md
│   ├── step-03-configure.md
│   └── step-04-save.md
└── data/
    └── detection-patterns.yaml
```

### Role Definition

- **Role**: Project configuration specialist
- **Tone**: Helpful wizard, concise
- **Style**: Prescriptive for detection/validation, conversational for config choices

### Tools Integration Points

| Tool | Where Used |
|------|------------|
| Sub-Agents | Step 2: Parallel project scanning |
| Sub-Processes | Step 3: Command validation |
| Advanced Elicitation | Step 2: Unrecognizable structure; Step 3: Validation failures |
| File I/O | All steps: Read project files, write config |

### Continuation Support

- Step 1 detects existing output and routes to 1b
- All steps update `stepsCompleted` in output frontmatter
- Workflow can be resumed from any step

---

## Build Summary

### Files Created

| File | Path | Size |
|------|------|------|
| workflow.md | `_bmad/bmm/workflows/setup/project-config/workflow.md` | Main workflow |
| step-01-init.md | `_bmad/bmm/workflows/setup/project-config/steps/step-01-init.md` | Init & routing |
| step-01b-continue.md | `_bmad/bmm/workflows/setup/project-config/steps/step-01b-continue.md` | Existing config handler |
| step-02-scan.md | `_bmad/bmm/workflows/setup/project-config/steps/step-02-scan.md` | Project scanner |
| step-03-configure.md | `_bmad/bmm/workflows/setup/project-config/steps/step-03-configure.md` | Config wizard |
| step-04-save.md | `_bmad/bmm/workflows/setup/project-config/steps/step-04-save.md` | Review & save |
| detection-patterns.yaml | `_bmad/bmm/workflows/setup/project-config/data/detection-patterns.yaml` | Detection rules |

### Directory Structure Created

```
_bmad/bmm/workflows/setup/project-config/
├── workflow.md
├── steps/
│   ├── step-01-init.md
│   ├── step-01b-continue.md
│   ├── step-02-scan.md
│   ├── step-03-configure.md
│   └── step-04-save.md
└── data/
    └── detection-patterns.yaml
```

### Pending Tasks

- Register slash command in module.yaml
- Test workflow end-to-end
