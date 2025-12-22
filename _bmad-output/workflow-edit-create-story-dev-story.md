---
title: Workflow Edit - create-story & dev-story
date: 2025-12-22
stepsCompleted: [1, 2, 3, 4, 5]
status: complete
targetWorkflows:
  - create-story
  - dev-story
userGoal: Add conditional documentation check from document-feature workflow
---

## Workflow Analysis

### Target Workflows

#### create-story
- **Path**: `_bmad/bmm/workflows/4-implementation/create-story/`
- **Name**: create-story
- **Module**: bmm
- **Format**: Legacy (workflow.yaml + instructions.xml)

#### dev-story
- **Path**: `_bmad/bmm/workflows/4-implementation/dev-story/`
- **Name**: dev-story
- **Module**: bmm
- **Format**: Legacy (workflow.yaml + instructions.xml)

#### Reference: document-feature
- **Path**: `_bmad/bmm/workflows/4-implementation/document-feature/`
- **Format**: New Standalone (workflow.md + steps/)
- **Key Pattern**: Conditional Documentation Guide

### Structure Analysis

#### create-story
- **Type**: Interactive document creation
- **Files**: workflow.yaml, instructions.xml, template.md, checklist.md
- **Steps**: 6 steps in XML (determine target, load artifacts, architecture analysis, web research, create story, update sprint)

#### dev-story
- **Type**: Autonomous action workflow
- **Files**: workflow.yaml, instructions.xml, checklist.md
- **Steps**: 10 steps in XML (load story, load context, detect review, mark in-progress, implement, test, validate, completion, report)

### Content Characteristics

#### create-story
- **Purpose**: Create comprehensive story files with developer context to prevent LLM mistakes
- **Instruction Style**: Prescriptive XML with detailed checks and actions
- **User Interaction**: Minimal - auto-discovers from sprint-status or accepts user input
- **Complexity**: High - exhaustive artifact analysis

#### dev-story
- **Purpose**: Execute story implementation following red-green-refactor
- **Instruction Style**: Prescriptive XML with commit contracts and continuous execution
- **User Interaction**: Minimal - autonomous with HALT conditions only
- **Complexity**: High - full implementation lifecycle

### Conditional Docs Pattern (from document-feature)

```markdown
# Conditional Documentation Guide (docs/CONDITIONAL_DOCS.md)

## Documentation Map

- docs/features/[feature-name].md
  - Conditions:
    - When working with [feature area]
    - When implementing [related functionality]
    - When troubleshooting [specific issues]
```

---

_Analysis completed on 2025-12-22_

---

## Improvement Goals

### Priority: IMPORTANT

**Goal:** Add conditional documentation check to both workflows so relevant feature docs are automatically loaded based on story context.

### Improvement Details

| Aspect | Decision |
|--------|----------|
| **Timing** | Check at START, before other context loading |
| **Matching Logic** | Match keywords in story title/description and epic context against conditions |
| **Presentation** | Auto-load relevant docs AND display brief note about what was loaded |
| **Workflows** | Both create-story and dev-story |

### Specific Changes Needed

#### create-story
- **Insert Point:** After step 1 (determine target story), before step 2 (load artifacts)
- **Action:** Check conditional docs, match against epic/story context, load relevant feature docs
- **Include In:** Story context that gets written to the story file

#### dev-story
- **Insert Point:** After step 1 (load story file), before step 2 (load project context)
- **Action:** Check conditional docs, match against story context, load relevant feature docs
- **Include In:** Developer context for implementation decisions

### Expected Behavior

```
1. Workflow starts, determines target story (e.g., "3-2-implement-auth-middleware")
2. NEW: Check docs/CONDITIONAL_DOCS.md exists
3. NEW: Parse conditions, match "auth" and "middleware" against entries
4. NEW: Find match: "docs/features/authentication.md"
   - Condition: "When working with user authentication"
5. NEW: Auto-load authentication.md, display:
   "📚 Relevant docs loaded: docs/features/authentication.md"
6. Continue with normal workflow, now with extra context
```

### Success Criteria

- [ ] Both workflows check for conditional docs at start
- [ ] Matching is semantic (keywords from story context)
- [ ] Relevant docs are loaded into context
- [ ] Brief notification shown to user
- [ ] Graceful handling if no conditional docs file exists
- [ ] Graceful handling if no matches found

---

_Goals documented on 2025-12-22_

---

## Improvement Log

### Changes Applied

#### 1. create-story/instructions.xml

| Change | Location | Details |
|--------|----------|---------|
| Added step 1b | After step 1, before step 2 | New conditional docs loading step |
| Updated GOTOs | Multiple locations in step 1 | All "GOTO step 2a" → "GOTO step 1b" to route through new step |
| Added conditional docs usage | Step 5 (story creation) | Include `{{conditional_docs_content}}` in story output |

**New Step 1b Logic:**
- Check if `docs/CONDITIONAL_DOCS.md` exists
- Extract keywords from story key, epic name, description
- Match against conditions in the guide
- Load matching feature docs into `{{conditional_docs_content}}`
- Display loaded docs to user

#### 2. dev-story/instructions.xml

| Change | Location | Details |
|--------|----------|---------|
| Added step 1b | After step 1, before step 2 | New conditional docs loading step |
| Added conditional docs usage | Step 2 (context loading) | Include `{{conditional_docs_content}}` in implementation context |

**New Step 1b Logic:**
- Same pattern as create-story
- Keywords extracted from story key, title, task descriptions
- Matched docs inform implementation decisions

### Files Modified

- `_bmad/bmm/workflows/4-implementation/create-story/instructions.xml`
- `_bmad/bmm/workflows/4-implementation/dev-story/instructions.xml`

### User Approval

- [x] Approved by user (2025-12-22)

---

_Improvements applied on 2025-12-22_

---

## Validation Results

| Check | Status | Notes |
|-------|--------|-------|
| Step 1b Added | PASS | Both workflows have the new step |
| GOTO Routing | PASS | All paths route through step 1b |
| Variable Usage | PASS | `{{conditional_docs_content}}` used correctly |
| XML Structure | INFO | Pre-existing XML entity issues (unrelated to changes) |

### Changes Verified

- `create-story/instructions.xml`: Step 1b at line 197, usage at lines 335-340
- `dev-story/instructions.xml`: Step 1b at line 133, usage at lines 182-186

---

## Completion Summary

### Transformation

| Workflow | Before | After |
|----------|--------|-------|
| create-story | Step 1 → Step 2 | Step 1 → Step 1b → Step 2 |
| dev-story | Step 1 → Step 2 | Step 1 → Step 1b → Step 2 |

### Key Improvements

1. Both workflows now check `docs/CONDITIONAL_DOCS.md` before loading context
2. Relevant feature docs auto-loaded based on story keyword matching
3. Existing knowledge surfaced to prevent reinventing patterns

### Next Steps

1. Test with a real story that has matching conditional docs
2. Ensure `docs/CONDITIONAL_DOCS.md` exists (run document-feature to create if needed)
3. Verify keyword matching works as expected

---

_Validation completed on 2025-12-22_

---

## Final Compliance Status

**Status:** COMPLETE
**Compliance Score:** 100%
**Date:** 2025-12-22

### Files Modified

| File | Changes |
|------|---------|
| `_bmad/bmm/workflows/4-implementation/create-story/instructions.xml` | Added step 1b, updated GOTOs, added conditional docs usage |
| `_bmad/bmm/workflows/4-implementation/dev-story/instructions.xml` | Added step 1b, added conditional docs usage |

### Feature Added

Both workflows now check `docs/CONDITIONAL_DOCS.md` for relevant feature documentation before loading other context. This ensures existing knowledge is surfaced to prevent reinventing patterns.

---

_Workflow editing completed on 2025-12-22_
