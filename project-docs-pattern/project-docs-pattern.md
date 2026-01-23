# Project Documentation Pattern

A reusable pattern for organizing project documentation, with templates and examples.

---

## Quick Start

1. Copy the [Directory Structure](#directory-structure) to your project
2. Use [Templates](#templates) to create each file type
3. Reference [Examples](#examples) for real implementations
4. Follow [Documentation Rules](#documentation-rules) for consistency

---

## Directory Structure

```text
docs/
├── README.md                      # Central hub (use: readme-root.template)
├── DOCUMENTATION_STANDARDS.md     # Writing rules (use: documentation-standards.template)
├── CONDITIONAL_DOCS.md            # Task-based nav (use: conditional-docs.template)
│
├── architecture/
│   ├── README.md                  # Section index (use: readme-section.template)
│   ├── overview.md                # System architecture (see: architecture-overview.example)
│   ├── technical-architecture.md  # Detailed patterns
│   └── adrs/
│       ├── README.md              # ADR index
│       └── adr-NNN-*.md           # Decisions (see: adr.example)
│
├── development/
│   ├── README.md                  # Section index
│   ├── getting-started.md         # Setup guide (see: getting-started.example)
│   ├── deployment.md              # Deploy procedures
│   └── troubleshooting.md         # Issue resolution (see: troubleshooting.example)
│
├── templates/
│   ├── README.md                  # Template index
│   ├── service-template.md        # Services (see: service-template.example)
│   ├── feature-template.md        # Features/modules
│   ├── repository-template.md     # Data access
│   └── error-template.md          # Error types
│
├── reference/
│   ├── README.md                  # Reference index
│   ├── data-models.md             # Entities & DTOs (see: data-models.example)
│   ├── api-contracts.md           # API specs
│   ├── services-catalog.md        # Service documentation
│   └── source-tree.md             # Codebase structure
│
├── testing/
│   ├── README.md                  # Testing index
│   ├── testing-strategy.md        # Approach (see: testing-strategy.example)
│   └── scripts/                   # Test automation
│
├── product/
│   ├── README.md                  # Product index
│   └── prd.md                     # Requirements (see: prd.example)
│
└── design/                        # (UI projects only)
    ├── README.md                  # Design index
    ├── design-system.md           # Tokens & components (see: design-system.example)
    └── screenshots/               # Mockups
```

---

## Templates

Reusable templates for creating documentation files.

| Template | Purpose | Use For |
|----------|---------|---------|
| [readme-root.template](project-docs-pattern/templates/readme-root.template.md) | Central documentation hub | `docs/README.md` |
| [readme-section.template](project-docs-pattern/templates/readme-section.template.md) | Directory index | Every folder's `README.md` |
| [template-file.template](project-docs-pattern/templates/template-file.template.md) | Component creation guide | Files in `docs/templates/` |
| [conditional-docs.template](project-docs-pattern/templates/conditional-docs.template.md) | Task-based navigation | `docs/CONDITIONAL_DOCS.md` |
| [documentation-standards.template](project-docs-pattern/templates/documentation-standards.template.md) | Writing rules | `docs/DOCUMENTATION_STANDARDS.md` |
| [getting-started.template](project-docs-pattern/templates/getting-started.template.md) | Developer onboarding | `docs/development/getting-started.md` |

---

## Examples

Concrete implementations showing patterns in action.

| Example | Demonstrates | Reference For |
|---------|--------------|---------------|
| [architecture-overview.example](project-docs-pattern/examples/architecture-overview.example.md) | System diagrams, layer docs | `docs/architecture/overview.md` |
| [getting-started.example](project-docs-pattern/examples/getting-started.example.md) | Setup guide format | `docs/development/getting-started.md` |
| [troubleshooting.example](project-docs-pattern/examples/troubleshooting.example.md) | Issue/solution format | `docs/development/troubleshooting.md` |
| [service-template.example](project-docs-pattern/examples/service-template.example.md) | Template file structure | `docs/templates/*.md` |
| [data-models.example](project-docs-pattern/examples/data-models.example.md) | Entity catalog format | `docs/reference/data-models.md` |
| [testing-strategy.example](project-docs-pattern/examples/testing-strategy.example.md) | Test approach docs | `docs/testing/testing-strategy.md` |
| [prd.example](project-docs-pattern/examples/prd.example.md) | Product requirements | `docs/product/prd.md` |
| [design-system.example](project-docs-pattern/examples/design-system.example.md) | Design tokens & specs | `docs/design/design-system.md` |
| [adr.example](project-docs-pattern/examples/adr.example.md) | Architecture decisions | `docs/architecture/adrs/adr-*.md` |

---

## Documentation Rules

### File Structure

**Frontmatter required on all files:**

```yaml
---
title: Document Title
description: One-line purpose
author: Author Name
date: YYYY-MM-DD
---
```

**Naming conventions:**

| Type | Pattern | Example |
|------|---------|---------|
| General docs | kebab-case | `getting-started.md` |
| Templates | `{name}-template.md` | `service-template.md` |
| ADRs | `adr-NNN-{title}.md` | `adr-001-database-choice.md` |

### Markdown Standards

- **Headers**: ATX-style only (`#`, `##`, `###`)
- **Header hierarchy**: Never skip levels (h1 → h2 → h3)
- **Code blocks**: Always include language tag

```swift
// Swift code
```

```bash
# Shell commands
```

```json
{ "json": "data" }
```

### Content Rules

| Rule | Description |
|------|-------------|
| No time estimates | Never include "this takes X hours" |
| No secrets | Never commit API keys, passwords |
| No absolute paths | Use relative paths for internal links |
| No orphan docs | Every doc must be linked from a README |
| No duplication | One document per topic |

### Cross-Referencing

```markdown
<!-- Internal links: relative paths -->
[Getting Started](../development/getting-started.md)

<!-- Section links: anchor tags -->
[Integrations Section](service-template.md#integrations)

<!-- Codebase links: relative to docs -->
[Example](../../src/services/EmailService.ts)
```

---

## Template File Structure

Files in `docs/templates/` follow this structure:

```markdown
# {Component} Template

## When to Use
- Bullet points on usage scenarios

## Quick Reference
| Aspect | Value |
|--------|-------|
| Location | `path/to/{Component}/` |
| Pattern | Pattern name |
| Naming | `{Name}{Component}.ext` |

## Directory Structure
(if applicable)

## Code Templates
Copy-paste code with {Placeholder} tokens

## Existing Patterns
Links to real implementations in codebase

## Integrations
Registration, config, Package.swift additions

## Anti-Patterns to Avoid
(if applicable)

## Checklist
- [ ] All completion steps

## References
Links to related templates and docs
```

---

## Placeholder Convention

| Placeholder | Case | Example |
|-------------|------|---------|
| `{Module}` | PascalCase | `Authentication` |
| `{module}` | camelCase | `authentication` |
| `{module-slug}` | kebab-case | `authentication` |
| `{Entity}` | PascalCase | `User` |
| `{entity}` | camelCase | `user` |
| `{Service}` | PascalCase | `Network` |

---

## Key Principles

1. **README at every level** - Each directory has an index
2. **Single source of truth** - One document per topic
3. **Task-oriented navigation** - CONDITIONAL_DOCS guides by task
4. **Templates link to reality** - Reference actual implementations
5. **Hierarchical headers** - Never skip levels
6. **No time estimates** - Focus on what, not when
