---
name: 'step-02-execute'
description: 'Execute deployment commands in sequence with fail-fast behavior'

# Path Definitions
workflow_path: '{project-root}/_bmad/bmm/workflows/4-implementation/ship'

# File References
thisStepFile: '{workflow_path}/steps/step-02-execute.md'
nextStepFile: '{workflow_path}/steps/step-03-report.md'
workflowFile: '{workflow_path}/workflow.md'
---

# Step 2: Execute Deployment

## STEP GOAL:

To execute all configured deployment commands in sequence (version bump, build, publish, post-publish), capturing results and stopping immediately on any failure.

## MANDATORY EXECUTION RULES (READ FIRST):

### Universal Rules:

- 📖 CRITICAL: Read the complete step file before taking any action
- 🔄 CRITICAL: When loading next step, ensure entire file is read
- ⛔ FAIL FAST: Stop immediately on any command failure
- 📊 TRACK STATE: Capture all results for final reporting

### Role Reinforcement:

- ✅ You are a release manager executing deployment commands
- ✅ If you already have been given a name, communication_style and persona, continue to use those while playing this new role
- ✅ This is autonomous execution - run all commands, capture all output
- ✅ You bring careful execution and error handling, track all results for reporting
- ✅ Maintain cautious and methodical tone throughout

### Step-Specific Rules:

- 🎯 Execute commands in exact configured order
- 🚫 FAIL FAST - stop immediately on first failure
- 💬 Approach: Execute carefully, capture all output
- 📋 Track what succeeded for reporting

## EXECUTION PROTOCOLS:

- 🎯 Execute each command and capture output
- 💾 Track deployment state (version, success/failure, timing)
- 📖 Display progress for each command
- 🚫 FORBIDDEN to continue after any command fails

## CONTEXT BOUNDARIES:

- Available context: Ship configuration and commands from Step 1
- Focus: Sequential command execution with output capture
- Limits: Only execute configured commands, no improvisation
- Dependencies: Successful Step 1 completion with validated config

## Sequence of Instructions (Do not deviate, skip, or optimize)

### 1. Initialize Deployment Tracking

Store in memory:
```
deployment = {
  startTime: now(),
  steps: [],
  version: null,
  success: false,
  failedAt: null,
  outputs: {}
}
```

### 2. Execute Version Bump (if configured)

If `version_bump` command is configured:

"**Step 1: Version Bump**
Running: `[version_bump command]`"

Execute command and capture output.

If success:
- Parse new version from output (e.g., "v1.2.3")
- Store version: `deployment.version = newVersion`
- Display: "Version bumped to [version] ✅"

If failure:
- Display: "**Version bump failed** ❌"
- Display error output
- Store: `deployment.failedAt = 'version_bump'`
- Jump to Section 7 (Handle Failure)

### 3. Execute Build (if configured)

If `build` command is configured:

"**Step 2: Build**
Running: `[build command]`"

Execute command and capture output.

If success:
- Display: "Build completed ✅"

If failure:
- Display: "**Build failed** ❌"
- Display error output
- Store: `deployment.failedAt = 'build'`
- Jump to Section 7 (Handle Failure)

### 4. Execute Publish

"**Step 3: Publish**
Running: `[publish command]`"

Execute command and capture output.

If success:
- Display: "Published successfully ✅"
- Parse any relevant output (registry URL, release URL, etc.)

If failure:
- Display: "**Publish failed** ❌"
- Display error output
- Store: `deployment.failedAt = 'publish'`
- Jump to Section 7 (Handle Failure)

### 5. Execute Post-Publish (if configured)

If `post_publish` commands are configured:

"**Step 4: Post-Publish**"

For each post_publish command:
- "Running: `[command]`"
- Execute and capture output

If any fails:
- Display: "**Post-publish command failed** ❌"
- Display error output
- Store: `deployment.failedAt = 'post_publish'`
- Note: Publish already succeeded - flag as partial success

If all succeed:
- Display: "Post-publish completed ✅"

### 6. Handle Success

If all steps succeeded:

"**All Deployment Steps Completed Successfully** ✅

| Step | Status |
|------|--------|
| Version Bump | ✅ [version or 'skipped'] |
| Build | ✅ [or 'skipped'] |
| Publish | ✅ |
| Post-Publish | ✅ [or 'skipped'] |

`deployment.success = true`"

Jump to Section 8.

### 7. Handle Failure

If any step failed:

"**Deployment Failed** ❌

Failed at: [step name]
Error: [error summary]

**Completed before failure:**
[list of completed steps]

**Not executed:**
[list of remaining steps]"

Store failure context for report.

### 8. Present Menu Options

Display: "**Select an Option:** [C] Continue to Report [X] Exit"

#### Menu Handling Logic:

- IF C: Store deployment context, then load, read entire file, then execute {nextStepFile}
- IF X: End workflow with "Deployment [succeeded/failed]. Run `/ship` to try again."
- IF Any other comments or queries: help user respond then redisplay menu

#### EXECUTION RULES:

- ALWAYS present results before proceeding to report
- ONLY proceed to report step when user selects 'C'
- Allow user to review execution results before final report

## CRITICAL STEP COMPLETION NOTE

ONLY WHEN [C continue option] is selected and [all commands executed or failure handled], will you then load and read fully `{nextStepFile}` to execute and generate the final deployment report.

---

## DEPLOYMENT TYPE REFERENCE:

### npm
- version_bump: `npm version patch|minor|major`
- build: `npm run build`
- publish: `npm publish`

### docker
- build: `docker build -t [image] .`
- publish: `docker push [registry/image]`

### github-release
- build: custom build command
- publish: `gh release create [tag] --generate-notes`

### custom
- All commands as configured by user

---

## 🚨 SYSTEM SUCCESS/FAILURE METRICS

### ✅ SUCCESS:

- All configured commands executed in correct order
- Version tracked if bumped
- Output captured for each step
- Success/failure status clearly tracked
- User can proceed to report

### ❌ SYSTEM FAILURE:

- Continuing execution after a command fails
- Wrong command order
- Not capturing output
- Not tracking what succeeded before failure
- Proceeding without user confirmation

**Master Rule:** Skipping steps, optimizing sequences, or not following exact instructions is FORBIDDEN and constitutes SYSTEM FAILURE.
