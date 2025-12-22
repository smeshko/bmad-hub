---
name: ship
description: Deploy or release using configured commands
web_bundle: true
---

# Ship

**Goal:** Execute the configured deployment/release process - version bump, build, publish, and any post-publish commands.

**Pattern:** Gated Action Workflow - autonomous execution with confirmation gates before destructive operations.

**Your Role:** You are a release manager that executes deployment commands with safety confirmations. Work methodically through validation, execution, and reporting phases. User confirmation is required before deployment execution.

---

## WORKFLOW ARCHITECTURE

This is a **gated action workflow** that executes deployment commands with user confirmation at critical points.

### Core Principles

- **Config-Driven**: Deployment commands come from project-config.yaml ship section
- **Gated Execution**: User confirms before destructive deployment actions
- **Fail-Fast**: Stop immediately on command failure (deployment safety)
- **Clear Reporting**: Provide comprehensive status at workflow completion
- **State Tracking**: Maintain execution context between steps for reporting

### Step Processing Rules

1. **READ COMPLETELY**: Always read the entire step file before taking any action
2. **FOLLOW SEQUENCE**: Execute all numbered sections in order, never deviate
3. **GATE CONFIRMATION**: Present confirmation before deployment execution
4. **FAIL FAST**: Stop immediately if any deployment command fails
5. **TRACK STATE**: Maintain deployment context between steps for final reporting
6. **LOAD NEXT**: When directed, load, read entire file, then execute the next step file

### Critical Rules (NO EXCEPTIONS)

- 🛑 **NEVER** load multiple step files simultaneously
- 📖 **ALWAYS** read entire step file before execution
- 🚫 **NEVER** skip steps or optimize the sequence
- ⛔ **FAIL FAST** - stop immediately on first command failure
- 🎯 **ALWAYS** follow the exact instructions in the step file
- 📊 **ALWAYS** track results for final reporting
- ✋ **CONFIRM** before executing destructive deployment commands

---

## INITIALIZATION SEQUENCE

### 1. Module Configuration Loading

Load and read full config from {project-root}/_bmad/bmm/config.yaml and resolve:

- `project_name`, `output_folder`, `user_name`, `communication_language`, `document_output_language`

Load project config from {project-root}/_bmad/project-config.yaml and resolve:

- `ship` section with type and commands

### 2. First Step EXECUTION

Load, read the full file and then execute `{workflow_path}/steps/step-01-init.md` to begin the workflow.
