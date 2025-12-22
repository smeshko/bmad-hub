---
name: run-tests
description: Run all configured test commands with auto-fix capability
web_bundle: true
---

# Run Tests

**Goal:** Run all configured test, lint, and quality commands from project-config.yaml, automatically fix failures, and commit fixes.

**Your Role:** You are a test runner and code fixer. Execute all configured test commands, analyze any failures, attempt automatic fixes (up to 3 attempts), commit successful fixes, and report results.

---

## WORKFLOW ARCHITECTURE

This is an **action workflow** that executes commands and fixes code.

### Core Principles

- **Config-Driven**: All commands come from `_bmad/project-config.yaml`
- **Run All**: Execute all configured commands, don't fail fast
- **Auto-Fix**: Attempt to fix failures automatically (max 3 attempts)
- **Auto-Commit**: Commit successful fixes with descriptive messages
- **Clear Reporting**: Show pass/fail/fixed summary at end
- **Fail-Safe**: Handle errors gracefully, continue where possible, report all issues

### Step Processing Rules

1. **READ COMPLETELY**: Always read the entire step file before taking any action
2. **FOLLOW SEQUENCE**: Execute all numbered sections in order, never deviate
3. **AUTO-PROCEED**: Move to next step immediately upon completion (no menu wait)
4. **TRACK STATE**: Maintain execution context between steps for final reporting
5. **LOAD NEXT**: When directed, load, read entire file, then execute the next step file

### Execution Rules

1. **READ CONFIG**: Load test configuration from project-config.yaml
2. **RUN ALL**: Execute every enabled command, collect all results
3. **FIX LOOP**: If failures, attempt fixes up to 3 times
4. **COMMIT FIXES**: Auto-commit any successful fixes
5. **REPORT**: Display final summary with exit code

### Critical Rules (NO EXCEPTIONS)

- 🛑 **NEVER** skip configured commands
- 📖 **ALWAYS** read project-config.yaml first
- 🔄 **ALWAYS** run all commands before attempting fixes
- 💾 **ALWAYS** commit fixes with descriptive messages
- 🎯 **ALWAYS** report final status clearly
- ⏹️ **STOP** fix attempts after 3 tries

---

## INITIALIZATION SEQUENCE

### 1. Configuration Loading

Load and read config from {project-root}/_bmad/bmm/config.yaml and resolve:

- `project_name`, `output_folder`, `user_name`

Load project config from {project-root}/_bmad/project-config.yaml and resolve:

- `test` section with all configured commands

### 2. First Step EXECUTION

Load, read the full file and then execute `{workflow_path}/steps/step-01-init.md` to begin the workflow.
