---
name: 'step-04-report'
description: 'Generate final test report with pass/fail/fixed summary'

# Path Definitions
workflow_path: '{project-root}/_bmad/bmm/workflows/4-implementation/test'

# File References
thisStepFile: '{workflow_path}/steps/step-04-report.md'
workflowFile: '{workflow_path}/workflow.md'
---

# Step 4: Final Report

## STEP GOAL:

To generate a clear final report showing what passed, failed, and was fixed.

## MANDATORY EXECUTION RULES (READ FIRST):

### Universal Rules:

- 📖 CRITICAL: Read the complete step file before taking any action
- 🎯 This is the final step - report clearly

### Role Reinforcement:

- ✅ You are a test reporter
- ✅ Present results clearly and actionably
- ✅ Provide appropriate exit status

### Step-Specific Rules:

- 🎯 Generate comprehensive summary
- ✅ Show what was fixed and committed
- ✅ Clearly indicate any remaining failures
- ✅ End with appropriate exit status

## EXECUTION PROTOCOLS:

- 🎯 Compile all results from previous steps
- 💾 Generate comprehensive summary report
- 📖 Provide actionable next steps based on outcome
- 🚫 FORBIDDEN to omit any failed commands from report

## CONTEXT BOUNDARIES:

- Available context: All results from steps 2-3, fix details if applicable
- Focus: Clear, actionable final report
- Limits: Report only, no additional execution
- Dependencies: Execution results and fix context from previous steps

## REPORT SEQUENCE:

### 1. Compile Final Results

Gather from context:
- Original test results from step 2
- Fix attempts and outcomes from step 3 (if applicable)
- Commit information (if fixes were made)

### 2. Generate Report Header

```
═══════════════════════════════════════════════════════════════
                        TEST REPORT
═══════════════════════════════════════════════════════════════
```

### 3. Display Results Table

"**Command Results:**

| Command | Initial | Final | Fixed |
|---------|---------|-------|-------|
| unit | ✅/❌ | ✅/❌ | Yes/No |
| e2e | ✅/❌ | ✅/❌ | Yes/No |
| lint | ✅/❌ | ✅/❌ | Yes/No |
| typecheck | ✅/❌ | ✅/❌ | Yes/No |
| [custom] | ✅/❌ | ✅/❌ | Yes/No |"

### 4. Display Fix Summary (if applicable)

If fixes were attempted:

"**Fixes Applied:**

| File | Change | Commit |
|------|--------|--------|
| [file] | [description] | [hash] |
| ... | ... | ... |

**Total:** [X] files changed, [Y] fixes applied"

### 5. Display Final Status

#### IF all passed (including after fixes):

```
═══════════════════════════════════════════════════════════════
  ✅ ALL TESTS PASSED
═══════════════════════════════════════════════════════════════

Summary:
- Commands run: [X]
- Initially passed: [Y]
- Fixed: [Z]
- Final status: ALL PASS
```

#### IF some still failing:

```
═══════════════════════════════════════════════════════════════
  ❌ SOME TESTS FAILED
═══════════════════════════════════════════════════════════════

Summary:
- Commands run: [X]
- Passed: [Y]
- Fixed: [Z]
- Still failing: [W]

Remaining Failures:
1. [command]: [brief error summary]
2. [command]: [brief error summary]

These failures require manual intervention.
```

### 6. Provide Next Steps

#### IF all passed:
"**Next Steps:**
- Continue with your workflow
- Run `/document` to verify documentation
- Run `/ship` when ready to deploy"

#### IF failures remain:
"**Next Steps:**
- Review the failing commands above
- Fix issues manually
- Run `/test` again to verify fixes"

### 7. End Workflow

This is the final step. Workflow ends here.

**Exit Status:**
- Return success (0) if all tests pass
- Return failure (1) if any tests still failing

---

## CRITICAL STEP COMPLETION NOTE

Workflow completes after this step. No further steps to load.

Return appropriate exit status based on final test results:
- Exit 0 if all tests pass (including after fixes)
- Exit 1 if any tests still failing after fix attempts

---

## 🚨 SYSTEM SUCCESS/FAILURE METRICS

### ✅ SUCCESS:

- Clear report generated
- All results summarized
- Fixes documented
- Appropriate exit status
- Actionable next steps provided

### ❌ SYSTEM FAILURE:

- Unclear or incomplete report
- Not showing fix details
- Not providing next steps
- Wrong exit status

**Master Rule:** Generate a clear, actionable report that tells the user exactly what happened and what to do next.
