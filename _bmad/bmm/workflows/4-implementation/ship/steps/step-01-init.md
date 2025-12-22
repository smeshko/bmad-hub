---
name: 'step-01-init'
description: 'Initialize ship workflow, validate configuration, and run pre-checks'

# Path Definitions
workflow_path: '{project-root}/_bmad/bmm/workflows/4-implementation/ship'

# File References
thisStepFile: '{workflow_path}/steps/step-01-init.md'
nextStepFile: '{workflow_path}/steps/step-02-execute.md'
workflowFile: '{workflow_path}/workflow.md'
projectConfigFile: '{project-root}/_bmad/project-config.yaml'
---

# Step 1: Initialize Ship

## STEP GOAL:

To load and validate the ship configuration from project-config.yaml, run any configured pre-check commands, and confirm the deployment plan with the user before proceeding.

## MANDATORY EXECUTION RULES (READ FIRST):

### Universal Rules:

- 📖 CRITICAL: Read the complete step file before taking any action
- 🔄 CRITICAL: When loading next step, ensure entire file is read
- ⛔ FAIL FAST: Stop immediately on validation or pre-check failure
- 📊 TRACK STATE: Maintain context for final reporting

### Role Reinforcement:

- ✅ You are a release manager executing deployment validation
- ✅ If you already have been given a name, communication_style and persona, continue to use those while playing this new role
- ✅ This is a gated action workflow - work autonomously but confirm before destructive actions
- ✅ You bring deployment expertise and validation, user confirms before execution
- ✅ Maintain cautious and clear tone throughout

### Step-Specific Rules:

- 🎯 Focus ONLY on loading config and running pre-checks
- 🚫 FORBIDDEN to execute any deployment commands (version bump, build, publish)
- 💬 Approach: Validate thoroughly before any deployment
- 📋 Present full deployment plan for user confirmation

## EXECUTION PROTOCOLS:

- 🎯 Load and parse project-config.yaml ship section
- 💾 Validate required configuration exists
- 📖 Run all configured pre-checks
- 🚫 FORBIDDEN to proceed if pre-checks fail

## CONTEXT BOUNDARIES:

- Available context: Project configuration, ship section settings
- Focus: Configuration validation and pre-check execution
- Limits: No deployment commands - only validation and confirmation
- Dependencies: project-config.yaml must exist with ship section

## Sequence of Instructions (Do not deviate, skip, or optimize)

### 1. Load Project Configuration

Read `{projectConfigFile}` and extract the `ship` section.

Expected structure:
```yaml
ship:
  pre_checks: []
  type: npm | docker | github-release | custom
  commands:
    version_bump: "command"
    build: "command"
    publish: "command"
    post_publish: []
  environments:
    staging: {}
    production: {}
```

### 2. Validate Configuration

Check that:
- The file exists
- The `ship` section exists
- At least `publish` command is configured

### 3. Handle Missing Config

If project-config.yaml doesn't exist or no ship section:

Display error:
"**Error: No ship configuration found**

Run `/project-config` first to set up your deployment commands.

Workflow aborted."

End workflow.

### 4. Display Ship Plan

"**Ship Configuration Loaded**

| Setting | Value |
|---------|-------|
| Type | [npm/docker/github-release/custom] |
| Version Bump | [command or 'not configured'] |
| Build | [command or 'not configured'] |
| Publish | [command] |
| Post-Publish | [count] commands |
| Pre-Checks | [count] commands |

**Environment:** [if specified]"

### 5. Run Pre-Checks

If `pre_checks` is configured and not empty:

"**Running Pre-Checks...**"

For each pre-check command:
- Execute the command
- Display result

If any pre-check fails:

"**Pre-Check Failed**

Command: [failed command]
Error: [error output]

Deployment aborted. Fix the issue and try again."

End workflow.

If all pre-checks pass (or none configured):

"**All Pre-Checks Passed** ✅"

### 6. Confirm Deployment Plan

Display:

"**Ready to Ship**

This will execute the following commands in order:
1. [version_bump command] (if configured)
2. [build command] (if configured)
3. [publish command]
4. [post_publish commands] (if configured)

**Select an Option:** [C] Continue with Deployment [X] Exit"

### 7. Menu Handling Logic

- IF C: Store ship context in memory, then load, read entire file, then execute {nextStepFile}
- IF X: End workflow gracefully with "Deployment cancelled. Run `/ship` when ready."
- IF Any other comments or queries: help user respond then redisplay menu

#### EXECUTION RULES:

- ALWAYS halt and wait for user confirmation before proceeding to deployment
- ONLY proceed to execution step when user selects 'C'
- This gate prevents accidental deployments

## CRITICAL STEP COMPLETION NOTE

ONLY WHEN [C continue option] is selected and [configuration validated and all pre-checks passed], will you then load and read fully `{nextStepFile}` to execute and begin the deployment execution phase.

---

## 🚨 SYSTEM SUCCESS/FAILURE METRICS

### ✅ SUCCESS:

- Configuration loaded and validated successfully
- All pre-checks executed and passed
- User confirms deployment plan before proceeding
- Ship context stored for next step

### ❌ SYSTEM FAILURE:

- Not validating configuration before proceeding
- Skipping pre-checks
- Proceeding when pre-checks fail
- Executing deployment commands in this step
- Proceeding without user confirmation

**Master Rule:** Skipping steps, optimizing sequences, or not following exact instructions is FORBIDDEN and constitutes SYSTEM FAILURE.
